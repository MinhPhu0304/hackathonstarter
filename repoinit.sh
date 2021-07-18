#!/bin/bash
set -ex
DIRNAME="$1"
REPO="$2"
KEY="$3"
EC2IP="$4"

mkdir -p $DIRNAME
cd $DIRNAME
git init
echo '{}' > package.json
jq ".name = \"$DIRNAME\"" package.json > tmp && mv tmp package.json
jq ".version = \"0.1.0\"" package.json > tmp && mv tmp package.json
jq ".private = true" package.json > tmp && mv tmp package.json
jq ".description = \"\"" package.json > tmp && mv tmp package.json
jq ".scripts = {}" package.json > tmp && mv tmp package.json
jq ".keywords = []" package.json > tmp && mv tmp package.json
jq ".author = \"\"" package.json > tmp && mv tmp package.json
jq ".license = \"UNLICENSED\"" package.json > tmp && mv tmp package.json
echo 'node_modules/' > .gitignore
git add .
git commit -m 'initial commit'

yarn add -D ts-node-dev
yarn add typescript
jq '.scripts.start = "ts-node-dev --transpile-only --respawn --rs src"' package.json > tmp && mv tmp package.json
git add .
git commit -m 'add ts-node-dev and start script'

yarn add express cors morgan
yarn add -D @types/express @types/cors @types/morgan
mkdir -p src
cat > src/index.ts <<- EOF
import * as express from 'express'
import * as cors from 'cors'
import * as morgan from 'morgan'

const app = express()
const port = 3001

app.use(cors())
app.use(morgan('dev'))
app.get('/', (req, res) => {
  res.send('Hello $DIRNAME!')
})

app.listen(port, () => {
  console.log(\`Example app listening at http://localhost:\${port}\`)
})
EOF
git add .
git commit -m 'add express'

yarn add -D @types/node
yarn add ts-node
echo '{}' > tsconfig.json
jq '.scripts.prod = "ts-node --transpile-only src"' package.json > tmp && mv tmp package.json
git add .
git commit -m 'add ts-node and prod script'

yarn add -D eslint typescript @typescript-eslint/parser \
  @typescript-eslint/eslint-plugin eslint-plugin-eslint-comments \
  eslint-plugin-import eslint-plugin-node eslint-plugin-promise \
  eslint-plugin-unicorn eslint-config-prettier eslint-config-airbnb-typescript
echo 'node_modules/' > .eslintignore
jq '.scripts.lint = "eslint . --ext .js,.jsx,.ts,.tsx"' package.json > tmp && mv tmp package.json
cat > .eslintrc.json <<- EOF
{
  "root": true,
  "parser": "@typescript-eslint/parser",
  "parserOptions": {
    "project": "./tsconfig.json"
  },
  "plugins": [],
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:@typescript-eslint/recommended-requiring-type-checking"
  ],
  "env": {
    "node": true
  },
  "rules": {
    "no-console": "off",
    "no-use-before-define": "off",
    "import/prefer-default-export": "off",
    "import/no-default-export": "error",
    "@typescript-eslint/explicit-function-return-type": "off",
    "@typescript-eslint/no-use-before-define": "off",
    "unicorn/prevent-abbreviations": "off",
    "unicorn/no-array-for-each": "off"
  }
}
EOF
jq '.extends = ["airbnb-typescript/base"] + .extends' .eslintrc.json > tmp && mv tmp .eslintrc.json
jq '.extends += ["plugin:eslint-comments/recommended"]' .eslintrc.json > tmp && mv tmp .eslintrc.json
jq '.extends += ["plugin:import/recommended"]' .eslintrc.json > tmp && mv tmp .eslintrc.json
jq '.extends += ["plugin:node/recommended-module"]' .eslintrc.json > tmp && mv tmp .eslintrc.json
jq '.extends += ["plugin:promise/recommended"]' .eslintrc.json > tmp && mv tmp .eslintrc.json
jq '.extends += ["plugin:unicorn/recommended"]' .eslintrc.json > tmp && mv tmp .eslintrc.json
jq '.extends += ["prettier"]' .eslintrc.json > tmp && mv tmp .eslintrc.json
echo '{}' > .prettierrc
jq '.tabWidth = 2' .prettierrc > tmp && mv tmp .prettierrc
jq '.useTabs = false' .prettierrc > tmp && mv tmp .prettierrc
jq '.semi = false' .prettierrc > tmp && mv tmp .prettierrc
jq '.singleQuote = true' .prettierrc > tmp && mv tmp .prettierrc
git add .
git commit -m 'add eslint and prettier'

mkdir -p .vscode
cat > .vscode/extensions.json <<- EOF
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode"
  ]
}
EOF
cat > .vscode/launch.json <<- EOF
{
  "version": "0.2.0",
  "configurations": [
    {
      "runtimeExecutable": "\${workspaceFolder}/node_modules/.bin/ts-node",
      "type": "pwa-node",
      "request": "launch",
      "name": "Launch Server",
      "skipFiles": [
        "<node_internals>/**"
      ],
      "program": "\${workspaceFolder}/src",
    }
  ]
}
EOF
git add .
git commit -m 'add vscode configuration'

cat > README.md <<- EOF
# $DIRNAME

## Available Scripts

In the project directory, you can run:

### \`yarn start\`

Runs the app in the development mode.\\
The server will restart when a file is modified.

### \`yarn prod\`

Runs the app in the production mode.

### \`yarn lint\`

Lints all JavaScript and TypeScript files.
EOF
git add .
git commit -m 'add README.md'

mkdir -p .github/workflows/
cat > .github/workflows/main.yml <<- EOF
name: CI
on:
  push:
    branches: [ main ]
  workflow_dispatch:
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Shitty ssh script
        run: |
          echo "\$SSH_PRIVATE_KEY" > ./key.pem
          chmod 600 ./key.pem
          mkdir -p ~/.ssh/
          ssh-keyscan -H $EC2IP >> ~/.ssh/known_hosts
          ssh -i ./key.pem ec2-user@$EC2IP << EOF
            cd $DIRNAME/
            git reset --hard && git pull --rebase
            rm -rf node_modules/ && yarn
            pm2 restart $DIRNAME
          EOF
        shell: bash
        env:
          SSH_PRIVATE_KEY: \${{secrets.SSH_PRIVATE_KEY}}
EOF
git add .
git commit -m 'add GitHub Actions script'

git remote add origin "git@github.com:$REPO.git"
git push -u --force origin main

cd -
./ec2init-run.sh "$KEY" "$EC2IP" "$REPO"

echo "cd $DIRNAME"
