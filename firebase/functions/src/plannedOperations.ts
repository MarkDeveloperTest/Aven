import {onCall, HttpsError} from "firebase-functions/v2/https";
import {requireVerifiedCaller} from "./auth";
import {sensitiveCallableOptions} from "./config";
import {logSecurityEvent} from "./logging";

function unsupportedCallable(
  operation: string,
  explanation: string
): ReturnType<typeof onCall> {
  return onCall(sensitiveCallableOptions, (request) => {
    const caller = requireVerifiedCaller(request);
    logSecurityEvent({
      operation,
      actorId: caller.uid,
      outcome: "denied",
      reasonCode: "not_implemented"
    });
    throw new HttpsError("unimplemented", explanation);
  });
}

export const createRelationship = unsupportedCallable(
  "createRelationship",
  "Direct relationship creation is disabled. Redeem an invitation instead."
);

export const resolveUnlinkingChoices = unsupportedCallable(
  "resolveUnlinkingChoices",
  "Relationship unlinking is not implemented yet."
);

export const exportAccountData = unsupportedCallable(
  "exportAccountData",
  "Account export is not implemented yet."
);

export const deleteAccountData = unsupportedCallable(
  "deleteAccountData",
  "Account deletion is not implemented yet."
);

export const generateRelationshipInsight = unsupportedCallable(
  "generateRelationshipInsight",
  "Relationship insight generation is not implemented yet."
);
