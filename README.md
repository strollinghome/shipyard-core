# Roadmap

-   [ ] Conduit pre-approvals
    -   [ ] ERC721
        -   [x] Solady
        -   [x] OpenZeppelin
        -   [ ] ERC721A
    -   [x] ERC1155
        -   [x] Solady
        -   [x] OpenZeppelin
-   [x] Onchain helpers
    -   [x] json
    -   [x] svg
-   [ ] Interfaces
    -   [ ] Redeemables?
        -   [ ] These are already defined in Redeemables repo
    -   [ ] SeaDrop?
        -   [ ] These are already defined in SeaDrop repo
    -   [ ] IERC4906?
        -   [ ] this is already defined in OpenZeppelin
    -   [x] Dynamic Metadata
    -   [x] Interface Delegation
    -   [x] PreapprovalForAll
    -   [ ] Queryable?
        -   [ ] maybe useful in tandem with interface delegation
    -   [x] SIPS 5, 6, 7, 10
-   [ ] Reference Implementations
    -   [x] IERC5912 Staking
    -   [ ] IERC4906 Metadata Updates
    -   [ ] IERCDynamicMetadata
    -   [ ] IERCInterfaceDelegation
    -   [x] AbstractSIP5
    -   [x] AbstractSIP6
    -   [x] AbstractSIP7
    -   [x] AbstractSIP10
-   [ ] SignedZone
    -   [ ] port from seaport repo

## Running ffi tests.

Currently, the ffi tests are the only way to test the output of ExampleNFT's tokenURI response. More options soon™.

In general, it's wise to be especially wary of ffi code. In the words of the Foundrybook, "It is generally advised to use this cheat code as a last resort, and to not enable it by default, as anyone who can change the tests of a project will be able to execute arbitrary commands on devices that run the tests."

# Environment configuration

To run the ffi tests locally, set `FOUNDRY_PROFILE='ffi'` in your `.env` file, and then source the `.env` file. This will permit Forge to make foreign calls (`ffi = true`) and read and write within the `./test-ffi/` directory. It also tells Forge to run the tests in the `./test-ffi/` directory instead of the tests in the `./test/` directory, which are run by default. Check out the `foundry.toml` file, where all of this and more is configured.

Both the local profile and the CI profile for the ffi tests use a low number of fuzz runs, because the ffi lifecycle is slow. Before yeeting a project to mainnet, it's advisable to crank up the number of fuzz runs to increase the likelihood of catching an issue. It'll take more time, but it increases the likelihood of catching an issue.

# Expected local behavior

The `ExampleNFT.t.sol` file will call `ExampleNFT.sol`'s `tokenURI` function, decode the base64 encoded response, write the decoded version to `./test-ffi/tmp/temp.json`, and then call the `process_json.js` file a few times to get string values. If the expected values and the actual values match, the test will pass. A `temp.json` file will be left behind. You can ignore it or delete it; Forge makes a new one on the fly if it's not there. And it's ignored in the `.gitignore` file, so there's no need to worry about pushing cruft or top secret metadata to a shared/public repo.

# Expected CI behavior

When a PR is opened or when a new commit is pushed, Github runs a series of actions defined in the files in `.github/workflows/*.yml`. The normal Forge tests and linting are set up in `test.yml`. The ffi tests are set up in `test-ffi.yml`. Forks of this repository can safely disregard it or if it's not necessary, remove it entirely.