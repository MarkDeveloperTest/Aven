import type {CallableRequest} from "firebase-functions/v2/https";
import {describe, expect, it} from "vitest";
import {requireVerifiedCaller} from "../../src/auth";

function requestWith(
  auth: unknown,
  app: unknown
): CallableRequest<unknown> {
  return {
    data: {},
    auth,
    app,
    rawRequest: {}
  } as unknown as CallableRequest<unknown>;
}

describe("callable caller verification", () => {
  it("requires both Firebase Authentication and App Check", () => {
    expect(
      () => requireVerifiedCaller(requestWith(undefined, undefined))
    ).toThrow(
      expect.objectContaining({code: "unauthenticated"})
    );
    expect(
      () => requireVerifiedCaller(
        requestWith({uid: "alice", token: {}}, undefined)
      )
    ).toThrow(
      expect.objectContaining({code: "failed-precondition"})
    );
    expect(
      requireVerifiedCaller(
        requestWith(
          {uid: "alice", token: {}},
          {appId: "verified-app", token: {}}
        )
      )
    ).toEqual({
      uid: "alice",
      appId: "verified-app"
    });

    expect(
      () => requireVerifiedCaller(
        requestWith(
          {uid: "alice", token: {}},
          {
            appId: "verified-app",
            token: {},
            alreadyConsumed: true
          }
        )
      )
    ).toThrow(
      expect.objectContaining({code: "permission-denied"})
    );
  });
});
