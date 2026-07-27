import {createHash} from "node:crypto";
import {Timestamp} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {requireAIAccess} from "./authorization";
import {requireVerifiedCaller} from "./auth";
import {
  aiProviderApiKey,
  aiProviderModel,
  aiProviderResponsesUrl,
  sensitiveCallableOptions
} from "./config";
import {requireConfiguredSecret, runCallable} from "./errors";
import {db} from "./firebase";
import {
  logProviderFailure,
  logSecurityEvent
} from "./logging";
import {enforceRateLimit} from "./rateLimit";
import {
  aiProviderResponseSchema,
  aiProxyInputSchema,
  parseInput,
  type AIProxyInput
} from "./validation";

const SYSTEM_INSTRUCTION = [
  "You are a careful relationship communication assistant.",
  "Use neutral, non-diagnostic language and acknowledge limited context.",
  "Do not assign blame, infer cheating, advise separation, manipulate,",
  "impersonate another person, or automatically send any generated text.",
  "Return only the requested assistance in the requested language."
].join(" ");

interface AIRequestClaim {
  readonly requestId: string;
  readonly cachedOutput: string | null;
}

interface ResolvedAIContext {
  readonly content: string;
  readonly contentHash: string;
}

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function configuredProvider(): {
  apiKey: string;
  model: string;
  url: URL;
} {
  const apiKey = requireConfiguredSecret(
    aiProviderApiKey.value(),
    "AI provider secret"
  );
  const model = aiProviderModel.value().trim();
  const rawUrl = aiProviderResponsesUrl.value().trim();
  if (model.length === 0 || rawUrl.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "The AI provider is not configured."
    );
  }

  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new HttpsError(
      "failed-precondition",
      "The AI provider URL is invalid."
    );
  }

  const emulatorAllowsLocalHTTP =
    process.env["FUNCTIONS_EMULATOR"] === "true"
    && ["localhost", "127.0.0.1"].includes(url.hostname);
  if (url.protocol !== "https:" && !emulatorAllowsLocalHTTP) {
    throw new HttpsError(
      "failed-precondition",
      "The AI provider URL must use HTTPS."
    );
  }

  return {apiKey, model, url};
}

async function claimAIRequest(
  userId: string,
  input: AIProxyInput,
  resolvedContext: ResolvedAIContext
): Promise<AIRequestClaim> {
  const requestId = sha256(
    `aven-ai-request-v1\u0000${userId}\u0000${input.idempotencyKey}`
  ).slice(0, 48);
  const reference = db.doc(`AIRequests/${requestId}`);
  const inputHash = sha256(
    JSON.stringify({
      scope: input.scope,
      relationshipId: input.relationshipId,
      task: input.task,
      contextCategory: input.context.category,
      consentVersion: input.consentVersion,
      contentHash: resolvedContext.contentHash,
      outputLanguage: input.outputLanguage
    })
  );

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (snapshot.exists) {
      if (
        snapshot.get("ownerId") !== userId
        || snapshot.get("inputHash") !== inputHash
      ) {
        throw new HttpsError(
          "already-exists",
          "The idempotency key has already been used."
        );
      }
      if (
        snapshot.get("status") === "completed"
        && typeof snapshot.get("output") === "string"
      ) {
        return {
          requestId,
          cachedOutput: snapshot.get("output") as string
        };
      }
      if (snapshot.get("status") === "processing") {
        const leaseExpiresAt: unknown =
          snapshot.get("leaseExpiresAt");
        if (
          leaseExpiresAt instanceof Timestamp
          && leaseExpiresAt.toMillis() > Date.now()
        ) {
          throw new HttpsError(
            "aborted",
            "The request is already being processed."
          );
        }
      }
    }

    const now = Timestamp.now();
    const existingCreatedAt: unknown = snapshot.exists
      ? snapshot.get("createdAt")
      : undefined;
    if (
      snapshot.exists
      && !(existingCreatedAt instanceof Timestamp)
    ) {
      throw new HttpsError(
        "internal",
        "The saved AI request state is invalid."
      );
    }
    const existingAttemptCount: unknown = snapshot.exists
      ? snapshot.get("attemptCount")
      : 0;
    if (
      typeof existingAttemptCount !== "number"
      || !Number.isSafeInteger(existingAttemptCount)
      || existingAttemptCount < 0
    ) {
      throw new HttpsError(
        "internal",
        "The saved AI request attempt state is invalid."
      );
    }
    transaction.set(reference, {
      ownerId: userId,
      relationshipId: input.relationshipId,
      scope: input.scope,
      task: input.task,
      inputHash,
      status: "processing",
      attemptCount: existingAttemptCount + 1,
      createdAt: existingCreatedAt ?? now,
      updatedAt: now,
      leaseExpiresAt: Timestamp.fromMillis(
        now.toMillis() + 60 * 1000
      ),
      expiresAt: Timestamp.fromMillis(
        now.toMillis() + 24 * 60 * 60 * 1000
      ),
      schemaVersion: 1
    });

    return {requestId, cachedOutput: null};
  });
}

async function resolveAIContext(
  userId: string,
  input: AIProxyInput
): Promise<ResolvedAIContext> {
  if (
    input.scope === "private"
    && input.context.category === "userAuthoredText"
  ) {
    return {
      content: input.context.text,
      contentHash: sha256(input.context.text)
    };
  }

  if (
    input.relationshipId === null
    || input.context.category !== "selectedMessages"
  ) {
    throw new HttpsError(
      "invalid-argument",
      "The AI context does not match its scope."
    );
  }

  const references = input.context.messageIds.map(
    (messageId) => db.doc(
      `relationships/${input.relationshipId}/messages/${messageId}`
    )
  );
  const snapshots = await db.getAll(...references);
  const messages = snapshots.map((snapshot) => {
    const body: unknown = snapshot.get("body");
    const senderId: unknown = snapshot.get("senderId");
    const deletedAt: unknown = snapshot.get("deletedAt");
    if (
      !snapshot.exists
      || typeof body !== "string"
      || body.length === 0
      || typeof senderId !== "string"
      || deletedAt !== undefined
    ) {
      throw new HttpsError(
        "failed-precondition",
        "A selected message is unavailable for analysis."
      );
    }
    return {
      speaker: senderId === userId ? "requester" : "partner",
      text: body
    };
  });
  const content = JSON.stringify({messages});
  if (content.length > 12_000) {
    throw new HttpsError(
      "invalid-argument",
      "The selected message context is too large."
    );
  }

  return {
    content,
    contentHash: sha256(content)
  };
}

async function requestProvider(
  userId: string,
  input: AIProxyInput,
  resolvedContext: ResolvedAIContext,
  provider: ReturnType<typeof configuredProvider>
): Promise<string> {
  let response: Response;
  try {
    response = await fetch(provider.url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${provider.apiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: provider.model,
        store: false,
        max_output_tokens: 800,
        input: [
          {
            role: "system",
            content: [
              {type: "input_text", text: SYSTEM_INSTRUCTION}
            ]
          },
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: JSON.stringify({
                  task: input.task,
                  outputLanguage: input.outputLanguage,
                  contextCategory: input.context.category,
                  content: resolvedContext.content
                })
              }
            ]
          }
        ]
      }),
      signal: AbortSignal.timeout(20_000)
    });
  } catch {
    logProviderFailure(userId, "network");
    throw new HttpsError(
      "unavailable",
      "The AI provider is temporarily unavailable."
    );
  }

  if (!response.ok) {
    logProviderFailure(userId, response.status);
    throw new HttpsError(
      "unavailable",
      "The AI provider rejected the request."
    );
  }

  const rawResponse: unknown = await response.json();
  const parsed = aiProviderResponseSchema.safeParse(rawResponse);
  if (!parsed.success) {
    logProviderFailure(userId, "invalid_response");
    throw new HttpsError(
      "internal",
      "The AI provider returned an invalid response."
    );
  }
  return parsed.data.output_text;
}

async function markAIRequestFailed(requestId: string): Promise<void> {
  await db.doc(`AIRequests/${requestId}`).update({
    status: "failed",
    leaseExpiresAt: Timestamp.now(),
    updatedAt: Timestamp.now()
  });
}

export const secureAIProxy = onCall(
  {
    ...sensitiveCallableOptions,
    secrets: [aiProviderApiKey],
    timeoutSeconds: 30,
    memory: "512MiB",
    maxInstances: 10,
    concurrency: 10
  },
  async (request) => {
    const caller = requireVerifiedCaller(request);

    return runCallable("secureAIProxy", caller.uid, async () => {
      const input = parseInput(aiProxyInputSchema, request.data);
      await enforceRateLimit({
        userId: caller.uid,
        operation: "secureAIProxy",
        limit: 12,
        windowSeconds: 5 * 60
      });
      await requireAIAccess(
        caller.uid,
        input.scope,
        input.relationshipId,
        input.context.category,
        input.consentVersion
      );

      const resolvedContext = await resolveAIContext(caller.uid, input);
      const provider = configuredProvider();
      const claim = await claimAIRequest(
        caller.uid,
        input,
        resolvedContext
      );
      if (claim.cachedOutput !== null) {
        return {
          requestId: claim.requestId,
          output: claim.cachedOutput,
          cached: true
        };
      }

      try {
        const output = await requestProvider(
          caller.uid,
          input,
          resolvedContext,
          provider
        );
        await db.doc(`AIRequests/${claim.requestId}`).update({
          status: "completed",
          output,
          completedAt: Timestamp.now(),
          leaseExpiresAt: Timestamp.now(),
          updatedAt: Timestamp.now()
        });
        logSecurityEvent({
          operation: "secureAIProxy",
          actorId: caller.uid,
          ...(input.relationshipId === null
            ? {}
            : {relationshipId: input.relationshipId}),
          outcome: "completed"
        });
        return {
          requestId: claim.requestId,
          output,
          cached: false
        };
      } catch (error: unknown) {
        await markAIRequestFailed(claim.requestId);
        throw error;
      }
    });
  }
);
