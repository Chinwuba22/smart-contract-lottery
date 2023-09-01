//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscirption, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vfrCoordinator,
            bytes32 gasLane,
            uint32 callbackGasLimit,
            uint64 subsriptionId,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subsriptionId == 0) {
            CreateSubscription createSubcription = new CreateSubscription();
            subsriptionId = createSubcription.createSubscription(
                vfrCoordinator,
                deployerKey
            );
            //Fund it
            FundSubscirption fundSubscription = new FundSubscirption();
            fundSubscription.fundSubscription(
                vfrCoordinator,
                subsriptionId,
                link,
                deployerKey
            );
        }
        vm.startBroadcast(deployerKey);
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vfrCoordinator,
            gasLane,
            callbackGasLimit,
            subsriptionId
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            vfrCoordinator,
            subsriptionId,
            deployerKey
        );
        return (raffle, helperConfig);
    }
}
