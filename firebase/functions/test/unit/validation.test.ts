import {describe, expect, it} from "vitest";
import {
  aiProxyInputSchema,
  archiveRelationshipInputSchema,
  createInvitationInputSchema,
  emergencyUnlinkInputSchema,
  redeemInvitationInputSchema,
  splitInvitationCode
} from "../../src/validation";

const idempotencyKey = "018f6f7e-1234-7abc-8def-123456789abc";

describe("callable input validation", () => {
  it("accepts a complete invitation request", () => {
    const result = createInvitationInputSchema.safeParse({
      relationshipType: "longDistance",
      relationshipStartDate: "2024-01-15T00:00:00.000+00:00",
      idempotencyKey
    });

    expect(result.success).toBe(true);
  });

  it("rejects unexpected invitation fields", () => {
    const result = createInvitationInputSchema.safeParse({
      relationshipType: "dating",
      relationshipStartDate: null,
      idempotencyKey,
      privileged: true
    });

    expect(result.success).toBe(false);
  });

  it("requires a relationship only for shared AI", () => {
    const privateResult = aiProxyInputSchema.safeParse({
      scope: "private",
      relationshipId: "relationship_123456789",
      task: "calmerRewrite",
      context: {
        category: "userAuthoredText",
        text: "Please rephrase this."
      },
      consentVersion: 1,
      outputLanguage: "en",
      idempotencyKey
    });
    const sharedResult = aiProxyInputSchema.safeParse({
      scope: "shared",
      relationshipId: null,
      task: "topicSummary",
      context: {
        category: "selectedMessages",
        messageIds: ["message_123456789"]
      },
      consentVersion: 1,
      outputLanguage: "uk",
      idempotencyKey
    });

    expect(privateResult.success).toBe(false);
    expect(sharedResult.success).toBe(false);
  });

  it("requires typed category consent for shared AI", () => {
    const rawSharedText = aiProxyInputSchema.safeParse({
      scope: "shared",
      relationshipId: "relationship_123456789",
      task: "topicSummary",
      context: {
        category: "userAuthoredText",
        text: "Unverified copied conversation text."
      },
      consentVersion: 1,
      outputLanguage: "en",
      idempotencyKey
    });
    const selectedMessages = aiProxyInputSchema.safeParse({
      scope: "shared",
      relationshipId: "relationship_123456789",
      task: "topicSummary",
      context: {
        category: "selectedMessages",
        messageIds: ["message_123456789"]
      },
      consentVersion: 1,
      outputLanguage: "en",
      idempotencyKey
    });

    expect(rawSharedText.success).toBe(false);
    expect(selectedMessages.success).toBe(true);
  });

  it("rejects unsupported consent versions and duplicate message IDs", () => {
    const unsupportedConsent = aiProxyInputSchema.safeParse({
      scope: "private",
      relationshipId: null,
      task: "translate",
      context: {
        category: "userAuthoredText",
        text: "Translate me."
      },
      consentVersion: 2,
      outputLanguage: "uk",
      idempotencyKey
    });
    const duplicateSelection = aiProxyInputSchema.safeParse({
      scope: "shared",
      relationshipId: "relationship_123456789",
      task: "topicSummary",
      context: {
        category: "selectedMessages",
        messageIds: [
          "message_123456789",
          "message_123456789"
        ]
      },
      consentVersion: 1,
      outputLanguage: "en",
      idempotencyKey
    });

    expect(unsupportedConsent.success).toBe(false);
    expect(duplicateSelection.success).toBe(false);
  });

  it("parses only the expected opaque invitation format", () => {
    const invitationId = "a".repeat(40);
    const secret = "B".repeat(43);
    const invitationCode = `${invitationId}.${secret}`;

    expect(
      redeemInvitationInputSchema.safeParse({
        invitationCode,
        idempotencyKey
      }).success
    ).toBe(true);
    expect(splitInvitationCode(invitationCode)).toEqual({
      invitationId,
      secret
    });
  });

  it("requires explicit emergency unlink confirmation", () => {
    const base = {
      relationshipId: "relationship_123456789",
      idempotencyKey
    };

    expect(
      archiveRelationshipInputSchema.safeParse(base).success
    ).toBe(true);
    expect(
      emergencyUnlinkInputSchema.safeParse({
        ...base,
        confirmation: "STOP_SHARING_NOW"
      }).success
    ).toBe(true);
    expect(
      emergencyUnlinkInputSchema.safeParse({
        ...base,
        confirmation: "yes"
      }).success
    ).toBe(false);
  });
});
