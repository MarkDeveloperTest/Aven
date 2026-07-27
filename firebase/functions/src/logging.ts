import {createHash} from "node:crypto";
import {logger} from "firebase-functions";

type SecurityOutcome = "accepted" | "denied" | "completed" | "failed";

interface SecurityLogFields {
  readonly operation: string;
  readonly actorId: string;
  readonly outcome: SecurityOutcome;
  readonly relationshipId?: string;
  readonly reasonCode?: string;
}

function pseudonymize(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}

export function logSecurityEvent(fields: SecurityLogFields): void {
  const metadata: Record<string, string> = {
    event: "security_operation",
    operation: fields.operation,
    actor: pseudonymize(fields.actorId),
    outcome: fields.outcome
  };

  if (fields.relationshipId !== undefined) {
    metadata["relationship"] = pseudonymize(fields.relationshipId);
  }
  if (fields.reasonCode !== undefined) {
    metadata["reasonCode"] = fields.reasonCode;
  }

  logger.info("Security operation", metadata);
}

export function logInternalFailure(
  operation: string,
  actorId: string,
  error: unknown
): void {
  const errorType = error instanceof Error ? error.name : "UnknownError";
  logger.error("Callable failed", {
    event: "callable_internal_failure",
    operation,
    actor: pseudonymize(actorId),
    errorType
  });
}

export function logProviderFailure(
  actorId: string,
  status: number | "network" | "invalid_response"
): void {
  logger.error("AI provider request failed", {
    event: "ai_provider_failure",
    actor: pseudonymize(actorId),
    providerStatus: status
  });
}
