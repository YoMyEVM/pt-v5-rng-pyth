module.exports = {
    plugins: ["prettier-plugin-solidity"],
    overrides: [
      {
        files: "*.sol",
        options: {
          compiler: "0.8.24",
          bracketSpacing: true,
          printWidth: 120,
          tabWidth: 4,
        },
      },
    ],
  };
  