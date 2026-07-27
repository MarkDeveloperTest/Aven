import {defineConfig} from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    globals: false,
    hookTimeout: 30_000,
    testTimeout: 15_000,
    restoreMocks: true
  }
});
