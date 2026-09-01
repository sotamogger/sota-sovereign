// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Sota Minds — a sovereign token for building the SOTA NFT.
//
// One CEO holds the pen and spends the treasury. Token holders hold the
// leash: any of them can propose to replace the CEO, rewrite the
// constitution, or open a raise, and a simple majority makes it so. Votes
// are weighted by tokens, snapshotted when the proposal is made, and open
// for three days. Nothing here is upgradeable except by that vote.
//
// Deliberately small. The treasury funds whoever ships the collection; the
// NFT's fees come back here. Everything else is governance.

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract SotaMinds is ERC20Votes {
    uint256 public constant THRESHOLD_PCT = 50;
    uint256 public constant VOTE_DURATION = 3 days;

    struct Proposal {
        address ceo;
        string constitution;
        uint256 volume;
        uint256 price;
        uint48 snapshot;
        uint256 votes;
        bool passed;
    }

    address public ceo;
    string public constitution = "Seed a SOTA NFT collection about the top AI researchers in the world - memy, fun, meant to moon. The treasury pays whoever ships the collection; the CEO spends it, the holders can replace the CEO, the constitution, or open a raise. NFT fees flow back here. This text is deliberately open and may be replaced by a vote.";
    uint256 public raise_volume;
    uint256 public raise_price = 0.00000001 ether;
    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public signed;

    event Spent(address indexed to, uint256 amount, string reason);
    event Proposed(uint256 indexed id, address indexed proposer, address ceo, string constitution, uint256 volume, uint256 price);
    event Signed(uint256 indexed id, address indexed signer, uint256 weight);
    event Passed(uint256 indexed id);

    constructor() ERC20("Sota Minds", "MINDS") EIP712("Sota Minds", "1") {
        ceo = msg.sender;
        _mint(msg.sender, 1e18);
    }

    receive() external payable {}

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // A raise is a window the holders vote open: a fixed volume of new tokens
    // at a fixed price, first come first served, until it's used up. Opening a
    // new one wipes whatever the last one left behind. No curve, no games —
    // you pay the price the holders set, or you wait for a better one.
    function buy() external payable {
        uint256 tokens_out = msg.value * 1e18 / raise_price;
        require(tokens_out <= raise_volume, "exceeds raise");
        raise_volume -= tokens_out;
        _mint(msg.sender, tokens_out);
    }

    function spend(address to, uint256 amount, string calldata reason) external {
        require(msg.sender == ceo, "not the ceo");
        (bool ok,) = to.call{value: amount}("");
        require(ok, "eth send failed");
        emit Spent(to, amount, reason);
    }

    function propose(address new_ceo, string calldata new_constitution, uint256 volume, uint256 price) external payable returns (uint256 id) {
        require(msg.value >= totalSupply() * raise_price / 2e18, "fee below half the vote");
        uint256 changes = (new_ceo != address(0) ? 1 : 0) + (bytes(new_constitution).length > 0 ? 1 : 0) + (volume > 0 ? 1 : 0);
        require(changes == 1, "one change per proposal");
        id = proposals.length;
        proposals.push(Proposal(new_ceo, new_constitution, volume, price, clock(), 0, false));
        emit Proposed(id, msg.sender, new_ceo, new_constitution, volume, price);
    }

    function sign(uint256 id) external {
        Proposal storage p = proposals[id];
        require(block.timestamp <= p.snapshot + VOTE_DURATION, "vote expired");
        require(!p.passed && !signed[id][msg.sender], "already");
        uint256 weight = getPastVotes(msg.sender, p.snapshot);
        require(weight > 0, "no votes");
        signed[id][msg.sender] = true;
        p.votes += weight;
        emit Signed(id, msg.sender, weight);
        if (p.votes * 100 <= THRESHOLD_PCT * getPastTotalSupply(p.snapshot)) return;
        p.passed = true;
        if (p.ceo != address(0)) ceo = p.ceo;
        if (bytes(p.constitution).length > 0) constitution = p.constitution;
        if (p.volume > 0) {
            raise_volume = p.volume;
            raise_price = p.price;
        }
        emit Passed(id);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (to != address(0) && delegates(to) == address(0)) _delegate(to, to);
        super._update(from, to, value);
    }
}
