# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

fork-test-ethereum :; FOUNDRY_PROFILE=fork forge test --fork-url $(MAINNET_RPC_ENDPOINT) -vvv

test_coverage :; forge coverage --report lcov -vvv && genhtml lcov.info -c ./gcov.css --branch-coverage --output-dir coverage

# Allow to spin a http-server, due this repository runs in a docker environment
http_server :; npx http-server -p 3000 coverage/