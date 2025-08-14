// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BoardRandom_V19 {
    IERC20 public token;
    address public owner;
    address public source1;
    address public source2;
    address public source3;

    uint256 public boardSize;
    uint256 public resetThreshold;

    mapping(uint256 => uint256) private excludedGeneration;
    uint256 public excludedCount;
    uint256 public currentGeneration;

    uint256 public lastRandomNumber;
    uint256 public lastGeneratedAt;

    event RandomNumberGenerated(uint256 number, uint256 timestamp);

    constructor(
        address _token,
        uint256 _boardSize,
        uint256 _resetThreshold
    ) {
        require(_boardSize > 0, "Board size must be > 0");
        require(_resetThreshold > 0 && _resetThreshold <= _boardSize, "Invalid reset threshold");

        owner = msg.sender;
        token = IERC20(_token);
        boardSize = _boardSize;
        resetThreshold = _resetThreshold;
        currentGeneration = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function setSource1(address _source1) external onlyOwner {
        require(_source1 != address(0), "Invalid address");
        source1 = _source1;
    }

    function setSource2(address _source2) external onlyOwner {
        require(_source2 != address(0), "Invalid address");
        source2 = _source2;
    }

    function setSource3(address _source3) external onlyOwner {
        require(_source3 != address(0), "Invalid address");
        source3 = _source3;
    }

    function generateRandom() external {
        require(boardSize > 0, "Board not initialized");

        uint256 entropy1 = uint256(
            keccak256(
                abi.encodePacked(
                    source1.balance,
                    source2.balance,
                    source3.balance
                )
            )
        );

        uint256 num1 = (entropy1 % boardSize) + 1;
        bool odd1 = num1 % 2 == 1;

        uint256 senderTokenBalance = token.balanceOf(msg.sender);
        uint256 entropy2 = uint256(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    senderTokenBalance
                )
            )
        );

        uint256 num2 = (entropy2 % boardSize) + 1;
        bool odd2 = num2 % 2 == 1;

        uint256 finalNum = ((num1 + num2) % boardSize) + 1;

        // Check exclusion via generation
        if (excludedGeneration[finalNum] == currentGeneration) {
            if (odd1 == odd2) {
                while (excludedGeneration[finalNum] == currentGeneration) {
                    finalNum++;
                    if (finalNum > boardSize) finalNum = 1;
                }
            } else {
                while (excludedGeneration[finalNum] == currentGeneration) {
                    if (finalNum == 1) finalNum = boardSize;
                    else finalNum--;
                }
            }
        }

        // Mark excluded for current generation
        excludedGeneration[finalNum] = currentGeneration;
        excludedCount++;

        // Cheap reset: just increment generation
        if (excludedCount >= resetThreshold) {
            currentGeneration++;
            excludedCount = 0;
        }

        lastRandomNumber = finalNum;
        lastGeneratedAt = block.timestamp;

        emit RandomNumberGenerated(finalNum, block.timestamp);
    }

    function isExcluded(uint256 number) external view returns (bool) {
        require(number >= 1 && number <= boardSize, "Invalid number");
        return excludedGeneration[number] == currentGeneration;
    }
}
