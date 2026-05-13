import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.js"],
    environment: "node",
    globals: false,
    testTimeout: 5000,
    setupFiles: ["test/setup.js"],
  },
});
