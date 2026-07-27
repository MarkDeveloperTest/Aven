import {logger} from "firebase-functions";
import {HttpsError} from "firebase-functions/v2/https";
import {afterEach, describe, expect, it, vi} from "vitest";
import {runCallable} from "../../src/errors";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("callable denial logging", () => {
  it("records only pseudonymous metadata for an expected denial", async () => {
    const info = vi
      .spyOn(logger, "info")
      .mockImplementation(() => undefined);
    const rawContent = "private message body must never be logged";

    await expect(
      runCallable("secureOperation", "sensitive-user-id", async () => {
        throw new HttpsError("permission-denied", rawContent);
      })
    ).rejects.toMatchObject({code: "permission-denied"});

    expect(info).toHaveBeenCalledOnce();
    const logged = JSON.stringify(info.mock.calls[0]);
    expect(logged).toContain("permission-denied");
    expect(logged).not.toContain("sensitive-user-id");
    expect(logged).not.toContain(rawContent);
  });
});
