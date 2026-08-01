import {HttpsError} from "firebase-functions/v2/https";
import {z} from "zod";

const idempotencyKeySchema = z.uuid();
const relationshipIdSchema = z
  .string()
  .min(16)
  .max(128)
  .regex(/^[A-Za-z0-9_-]+$/u);
const messageIdSchema = z
  .string()
  .min(1)
  .max(128)
  .regex(/^[A-Za-z0-9_-]+$/u);
const consentVersionSchema = z.literal(1);
const linkTokenSchema = z
  .string()
  .regex(/^[a-f0-9]{40}\.[A-Za-z0-9_-]{43}$/u);

export function normalizeManualPairingCode(value: string): string {
  return value.replace(/[\s-]/gu, "").toUpperCase();
}

const manualPairingCodeSchema = z
  .string()
  .min(6)
  .max(16)
  .transform(normalizeManualPairingCode)
  .pipe(z.string().regex(/^[2-9A-HJ-NP-Z]{6}$/u));

export const createInvitationInputSchema = z
  .object({
    relationshipType: z.enum([
      "dating",
      "longDistance",
      "engaged",
      "married",
      "unspecified"
    ]),
    relationshipStartDate: z.iso.datetime({offset: true}).nullable(),
    idempotencyKey: idempotencyKeySchema
  })
  .strict();

export const revokeInvitationInputSchema = z
  .object({
    invitationId: z.string().regex(/^[a-f0-9]{40}$/u),
    idempotencyKey: idempotencyKeySchema
  })
  .strict();

export const redeemInvitationInputSchema = z.discriminatedUnion("kind", [
  z
    .object({
      kind: z.literal("token"),
      value: linkTokenSchema,
      idempotencyKey: idempotencyKeySchema
    })
    .strict(),
  z
    .object({
      kind: z.literal("code"),
      value: manualPairingCodeSchema,
      idempotencyKey: idempotencyKeySchema
    })
    .strict()
]);

const aiContextSchema = z.discriminatedUnion("category", [
  z
    .object({
      category: z.literal("userAuthoredText"),
      text: z.string().min(1).max(12_000)
    })
    .strict(),
  z
    .object({
      category: z.literal("selectedMessages"),
      messageIds: z
        .array(messageIdSchema)
        .min(1)
        .max(50)
        .refine(
          (messageIds) => new Set(messageIds).size === messageIds.length,
          "Selected message identifiers must be unique."
        )
    })
    .strict()
]);

export const aiProxyInputSchema = z
  .object({
    scope: z.enum(["private", "shared"]),
    relationshipId: relationshipIdSchema.nullable(),
    task: z.enum([
      "calmerRewrite",
      "topicSummary",
      "conversationPrompt",
      "translate"
    ]),
    context: aiContextSchema,
    consentVersion: consentVersionSchema,
    outputLanguage: z.enum(["en", "uk"]),
    idempotencyKey: idempotencyKeySchema
  })
  .strict()
  .superRefine((value, context) => {
    if (value.scope === "shared" && value.relationshipId === null) {
      context.addIssue({
        code: "custom",
        path: ["relationshipId"],
        message: "A relationship is required for shared AI."
      });
    }
    if (value.scope === "private" && value.relationshipId !== null) {
      context.addIssue({
        code: "custom",
        path: ["relationshipId"],
        message: "Private AI must not include a relationship identifier."
      });
    }
    if (
      value.scope === "private"
      && value.context.category !== "userAuthoredText"
    ) {
      context.addIssue({
        code: "custom",
        path: ["context", "category"],
        message: "Private AI accepts only user-authored text."
      });
    }
    if (
      value.scope === "shared"
      && value.context.category !== "selectedMessages"
    ) {
      context.addIssue({
        code: "custom",
        path: ["context", "category"],
        message: "Shared AI requires an explicit selected-message context."
      });
    }
  });

export const aiProviderResponseSchema = z
  .object({
    output_text: z.string().min(1).max(20_000)
  })
  .passthrough();

export type CreateInvitationInput = z.infer<
  typeof createInvitationInputSchema
>;
export type RevokeInvitationInput = z.infer<
  typeof revokeInvitationInputSchema
>;
export type RedeemInvitationInput = z.infer<
  typeof redeemInvitationInputSchema
>;
export type AIProxyInput = z.infer<typeof aiProxyInputSchema>;

export const archiveRelationshipInputSchema = z
  .object({
    relationshipId: relationshipIdSchema,
    idempotencyKey: idempotencyKeySchema
  })
  .strict();

export const emergencyUnlinkInputSchema = z
  .object({
    relationshipId: relationshipIdSchema,
    idempotencyKey: idempotencyKeySchema,
    confirmation: z.literal("STOP_SHARING_NOW")
  })
  .strict();

export type ArchiveRelationshipInput = z.infer<
  typeof archiveRelationshipInputSchema
>;
export type EmergencyUnlinkInput = z.infer<
  typeof emergencyUnlinkInputSchema
>;

export function parseInput<T>(
  schema: z.ZodType<T>,
  input: unknown
): T {
  const result = schema.safeParse(input);
  if (!result.success) {
    throw new HttpsError(
      "invalid-argument",
      "The request payload is invalid.",
      {
        fields: result.error.issues.map((issue) => issue.path.join("."))
      }
    );
  }
  return result.data;
}

export function splitLinkToken(token: string): {
  invitationId: string;
  secret: string;
} {
  const separator = token.indexOf(".");
  if (separator <= 0) {
    throw new HttpsError(
      "invalid-argument",
      "The invitation code is invalid."
    );
  }

  return {
    invitationId: token.slice(0, separator),
    secret: token.slice(separator + 1)
  };
}
