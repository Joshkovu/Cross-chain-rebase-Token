// SPDX-License-Identifier:MIT

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
// import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract BridgeTokensScript is Script {
    function run(
        address receiverAddress,
        uint64 destinationChainSelector,
        address linkAddress,
        address tokenToSendAddress,
        address routerAddress,
        uint256 amountToSend
    ) public {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: tokenToSendAddress,
            amount: amountToSend
        });
        // CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.startBroadcast();
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkAddress,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200000})
            )
        });
        // 1. deploy the vault and rebase token
        // 2. grant the vault mint and burn role on the rebase token
        // 3. add some liquidity to the vault
        IRouterClient(routerAddress).ccipSend(
            destinationChainSelector,
            message
        );
        uint256 ccipFee = IRouterClient(routerAddress).getFee(
            destinationChainSelector,
            message
        );
        IERC20(linkAddress).approve(routerAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);
        // ccipLocalSimulatorFork.requestLinkFromFaucet(receiverAddress, ccipFee);
        vm.stopBroadcast();
    }
}
