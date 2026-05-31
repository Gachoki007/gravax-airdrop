// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract GravaxQuest {

    // ─── Constants ───────────────────────────────────────────
    uint256 public constant QUEST_FOLLOW_X       = 0;
    uint256 public constant QUEST_CONNECT_WALLET = 1;
    uint256 public constant QUEST_LINK_X         = 2;
    uint256 public constant QUEST_CCHAIN_ADDR    = 3;
    uint256 public constant TOTAL_QUESTS         = 4;

    // ─── State ───────────────────────────────────────────────
    address public owner;
    IERC20  public grav;

    // Rewards in GRAV (18 decimals): 50, 100, 100, 50
    uint256[4] public questRewards = [
        50  * 10**18,
        100 * 10**18,
        100 * 10**18,
        50  * 10**18
    ];

    // user => questId => completed
    mapping(address => mapping(uint256 => bool)) public questDone;
    // user => total GRAV earned
    mapping(address => uint256) public totalEarned;
    // unique participants counter
    uint256 public participantCount;
    mapping(address => bool) public isParticipant;

    // ─── Events ──────────────────────────────────────────────
    event QuestCompleted(address indexed user, uint256 indexed questId, uint256 reward);
    event RewardsDeposited(uint256 amount);
    event RewardsWithdrawn(uint256 amount);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // ─── Modifiers ───────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ─── Constructor ─────────────────────────────────────────
    constructor(address _gravToken) {
        owner = msg.sender;
        grav  = IERC20(_gravToken);
    }

    // ─── Owner: mark one quest complete ──────────────────────
    function completeQuest(address user, uint256 questId) external onlyOwner {
        require(questId < TOTAL_QUESTS, "Invalid quest");
        require(!questDone[user][questId], "Already completed");

        questDone[user][questId] = true;
        uint256 reward = questRewards[questId];
        totalEarned[user] += reward;

        if (!isParticipant[user]) {
            isParticipant[user] = true;
            participantCount++;
        }

        require(grav.transfer(user, reward), "Transfer failed");
        emit QuestCompleted(user, questId, reward);
    }

    // ─── Owner: batch complete quests ────────────────────────
    function completeQuestsBatch(
        address[] calldata users,
        uint256[] calldata questIds
    ) external onlyOwner {
        require(users.length == questIds.length, "Length mismatch");
        for (uint256 i = 0; i < users.length; i++) {
            uint256 qid  = questIds[i];
            address user = users[i];
            if (qid < TOTAL_QUESTS && !questDone[user][qid]) {
                questDone[user][qid] = true;
                uint256 reward = questRewards[qid];
                totalEarned[user] += reward;
                if (!isParticipant[user]) {
                    isParticipant[user] = true;
                    participantCount++;
                }
                require(grav.transfer(user, reward), "Transfer failed");
                emit QuestCompleted(user, qid, reward);
            }
        }
    }

    // ─── Owner: update a reward amount ───────────────────────
    function setQuestReward(uint256 questId, uint256 newReward) external onlyOwner {
        require(questId < TOTAL_QUESTS, "Invalid quest");
        questRewards[questId] = newReward;
    }

    // ─── Owner: deposit GRAV into contract ───────────────────
    function depositRewards(uint256 amount) external onlyOwner {
        require(grav.transferFrom(msg.sender, address(this), amount), "Deposit failed");
        emit RewardsDeposited(amount);
    }

    // ─── Owner: withdraw leftover GRAV ───────────────────────
    function withdrawRewards(uint256 amount) external onlyOwner {
        require(grav.transfer(owner, amount), "Withdraw failed");
        emit RewardsWithdrawn(amount);
    }

    // ─── Owner: transfer ownership ───────────────────────────
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ─── View: all quests for a user ─────────────────────────
    function getUserProgress(address user) external view returns (bool[4] memory progress) {
        for (uint256 i = 0; i < TOTAL_QUESTS; i++) {
            progress[i] = questDone[user][i];
        }
    }

    // ─── View: contract GRAV balance ─────────────────────────
    function contractBalance() external view returns (uint256) {
        return grav.balanceOf(address(this));
    }
}
