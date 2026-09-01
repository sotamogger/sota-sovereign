// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SotaMinds} from "../src/SotaMinds.sol";

contract SotaMindsTest is Test {
    SotaMinds coin;
    address ceo = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        coin = new SotaMinds();
        vm.deal(address(coin), 5 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_bootstrap_ceo_and_supply() public view {
        assertEq(coin.ceo(), ceo);
        assertEq(coin.balanceOf(ceo), 1e18);
        assertEq(coin.totalSupply(), 1e18);
    }

    function test_buy_reverts_before_raise() public {
        vm.prank(alice);
        vm.expectRevert("exceeds raise");
        coin.buy{value: 1 ether}();
    }

    function test_ceo_opens_raise_then_buy() public {
        // sole holder (this) opens a raise via a passing proposal
        vm.warp(block.timestamp + 1);
        uint256 fee = coin.totalSupply() * 0.00000001 ether / 2e18;
        uint256 id = coin.propose{value: fee}(address(0), "", 1_000_000e18, 0.00000001 ether);
        vm.warp(block.timestamp + 1);
        coin.sign(id);
        (,,,,,, bool passed) = coin.proposals(id);
        assertTrue(passed);
        assertEq(coin.raise_volume(), 1_000_000e18);

        // now anyone can buy at the fixed price
        vm.prank(alice);
        coin.buy{value: 0.001 ether}();
        assertEq(coin.balanceOf(alice), 0.001 ether * 1e18 / 0.00000001 ether);
    }

    function test_buy_cannot_exceed_volume() public {
        vm.warp(block.timestamp + 1);
        uint256 fee = coin.totalSupply() * 0.00000001 ether / 2e18;
        uint256 id = coin.propose{value: fee}(address(0), "", 100e18, 0.00000001 ether);
        vm.warp(block.timestamp + 1);
        coin.sign(id);
        vm.prank(alice);
        vm.expectRevert("exceeds raise");
        coin.buy{value: 1 ether}(); // would mint way more than 100 tokens
    }

    function test_spend_only_ceo() public {
        uint256 before = bob.balance;
        coin.spend(bob, 1 ether, "pay for art");
        assertEq(bob.balance, before + 1 ether);

        vm.prank(alice);
        vm.expectRevert("not the ceo");
        coin.spend(alice, 1 ether, "steal");
    }

    function test_one_change_per_proposal() public {
        vm.warp(block.timestamp + 1);
        uint256 fee = coin.totalSupply() * 0.00000001 ether / 2e18;
        vm.expectRevert("one change per proposal");
        coin.propose{value: fee}(alice, "new mission", 0, 0); // two changes
        vm.expectRevert("one change per proposal");
        coin.propose{value: fee}(address(0), "", 0, 0); // zero changes
    }

    function test_proposal_fee_floor() public {
        vm.warp(block.timestamp + 1);
        vm.expectRevert("fee below half the vote");
        coin.propose{value: 0}(alice, "", 0, 0);
    }

    function test_ceo_handover_by_vote() public {
        vm.warp(block.timestamp + 1);
        uint256 fee = coin.totalSupply() * 0.00000001 ether / 2e18;
        uint256 id = coin.propose{value: fee}(alice, "", 0, 0);
        vm.warp(block.timestamp + 1);
        coin.sign(id);
        assertEq(coin.ceo(), alice);
    }

    function test_vote_expires() public {
        vm.warp(block.timestamp + 1);
        uint256 fee = coin.totalSupply() * 0.00000001 ether / 2e18;
        uint256 id = coin.propose{value: fee}(alice, "", 0, 0);
        vm.warp(block.timestamp + 3 days + 2);
        vm.expectRevert("vote expired");
        coin.sign(id);
    }

    function test_minority_cannot_pass() public {
        // open a raise, sell most supply to bob so `this` is a minority
        vm.warp(block.timestamp + 1);
        uint256 fee = coin.totalSupply() * 0.00000001 ether / 2e18;
        uint256 rid = coin.propose{value: fee}(address(0), "", 100_000_000e18, 0.00000001 ether);
        vm.warp(block.timestamp + 1);
        coin.sign(rid);
        vm.prank(bob);
        coin.buy{value: 0.05 ether}(); // bob gets 5,000,000e18 >> this's 1e18
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // `this` (dust) proposes and signs alone -> should not pass
        uint256 id = coin.propose{value: coin.totalSupply() * coin.raise_price() / 2e18}(alice, "", 0, 0);
        vm.warp(block.timestamp + 1);
        coin.sign(id);
        (,,,,,, bool passed) = coin.proposals(id);
        assertFalse(passed);
        assertEq(coin.ceo(), address(this)); // unchanged
    }
}
