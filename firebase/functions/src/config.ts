import {defineSecret, defineString} from "firebase-functions/params";
import type {CallableOptions} from "firebase-functions/v2/https";

export const PRIMARY_REGION = "europe-west2";

export const invitationSigningSecret = defineSecret(
  "INVITATION_SIGNING_SECRET"
);

export const aiProviderApiKey = defineSecret("AI_PROVIDER_API_KEY");
export const aiProviderResponsesUrl = defineString(
  "AI_PROVIDER_RESPONSES_URL",
  {default: ""}
);
export const aiProviderModel = defineString(
  "AI_PROVIDER_MODEL",
  {default: ""}
);

export const sensitiveCallableOptions: CallableOptions = {
  region: PRIMARY_REGION,
  enforceAppCheck: true,
  consumeAppCheckToken: true,
  timeoutSeconds: 30,
  memory: "256MiB",
  maxInstances: 20,
  concurrency: 20
};

export const pairingCallableOptions: CallableOptions = {
  region: PRIMARY_REGION,
  enforceAppCheck: false,
  timeoutSeconds: 30,
  memory: "256MiB",
  maxInstances: 20,
  concurrency: 20
};
