// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol"; // Adjust path if your interface is elsewhere
import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol"; // For CCIP structs

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowlist, address _rnmProxy, address _router)
        TokenPool(_token, _allowlist, _rnmProxy, _router)
    {
        // Constructor body (if any additional logic is needed)
    }

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);

        // Decode the original sender's address
        address receiver = abi.decode(lockOrBurnIn.receiver, (address));

        // Fetch the user's current interest rate from the rebase token
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(receiver);

        // Burn the specified amount of tokens from this pool contract
        // CCIP transfers tokens to the pool before lockOrBurn is called
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        // Prepare the output data for CCIP
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate) // Encode the interest rate to send cross-chain
        });
        // No explicit return statement is needed due to the named return variable
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        override
        returns (Pool.ReleaseOrMintOutV1 memory /* releaseOrMintOut */ )
    {
        // Named return optional
        _validateReleaseOrMint(releaseOrMintIn);

        // Decode the user interest rate sent from the source pool
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));

        // The receiver address is directly available
        address receiver = releaseOrMintIn.receiver;

        // Mint tokens to the receiver, applying the propagated interest rate
        IRebaseToken(address(i_token)).mint(
            receiver,
            releaseOrMintIn.amount,
            userInterestRate // Pass the interest rate to the rebase token's mint function
        );

        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }
}
