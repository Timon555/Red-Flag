module.exports = {
  env: {es2022: true, node: true},
  parserOptions: {ecmaVersion: 2022},
  extends: ["eslint:recommended", "google"],
  rules: {
    "quotes": ["error", "double", {allowTemplateLiterals: true}],
    "max-len": ["error", {code: 80, ignoreStrings: true,
      ignoreTemplateLiterals: true}],
    "require-jsdoc": "off",
  },
  overrides: [{files: ["test/**"], rules: {"valid-jsdoc": "off"}}],
};
