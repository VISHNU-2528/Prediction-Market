// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PredictionMarket
 * @dev A decentralized prediction market contract where users can create markets,
 * place bets on outcomes, and claim winnings based on resolved results.
 */
contract PredictionMarket {
    
    struct Market {
        uint256 id;
        string question;
        string[] options;
        uint256 endTime;
        uint256 totalPool;
        mapping(uint256 => uint256) optionPools;
        mapping(address => mapping(uint256 => uint256)) userBets;
        uint256 winningOption;
        bool resolved;
        address creator;
    }
    
    mapping(uint256 => Market) public markets;
    mapping(address => uint256[]) public userMarkets;
    uint256 public marketCounter;
    uint256 public constant MIN_BET = 0.01 ether;
    address public owner;
    
    event MarketCreated(uint256 indexed marketId, string question, address creator);
    event BetPlaced(uint256 indexed marketId, address bettor, uint256 option, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 winningOption);
    event WinningsClaimed(uint256 indexed marketId, address winner, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier marketExists(uint256 _marketId) {
        require(_marketId < marketCounter, "Market does not exist");
        _;
    }
    
    modifier marketActive(uint256 _marketId) {
        require(block.timestamp < markets[_marketId].endTime, "Market has ended");
        require(!markets[_marketId].resolved, "Market already resolved");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Creates a new prediction market
     * @param _question The question/event to predict
     * @param _options Array of possible outcomes
     * @param _duration Duration in seconds until market closes
     */
    function createMarket(
        string memory _question,
        string[] memory _options,
        uint256 _duration
    ) external returns (uint256) {
        require(bytes(_question).length > 0, "Question cannot be empty");
        require(_options.length >= 2, "Market needs at least 2 options");
        require(_duration > 0, "Duration must be positive");
        
        uint256 marketId = marketCounter++;
        Market storage newMarket = markets[marketId];
        
        newMarket.id = marketId;
        newMarket.question = _question;
        newMarket.options = _options;
        newMarket.endTime = block.timestamp + _duration;
        newMarket.totalPool = 0;
        newMarket.winningOption = type(uint256).max;
        newMarket.resolved = false;
        newMarket.creator = msg.sender;
        
        userMarkets[msg.sender].push(marketId);
        
        emit MarketCreated(marketId, _question, msg.sender);
        return marketId;
    }
    
    /**
     * @dev Places a bet on a specific outcome in a market
     * @param _marketId The ID of the market to bet on
     * @param _option The option index to bet on (0-based)
     */
    function placeBet(uint256 _marketId, uint256 _option) 
        external 
        payable 
        marketExists(_marketId) 
        marketActive(_marketId) 
    {
        require(msg.value >= MIN_BET, "Bet amount too low");
        require(_option < markets[_marketId].options.length, "Invalid option");
        
        Market storage market = markets[_marketId];
        
        market.userBets[msg.sender][_option] += msg.value;
        market.optionPools[_option] += msg.value;
        market.totalPool += msg.value;
        
        emit BetPlaced(_marketId, msg.sender, _option, msg.value);
    }
    
    /**
     * @dev Resolves a market by setting the winning option (only owner can resolve)
     * @param _marketId The ID of the market to resolve
     * @param _winningOption The index of the winning option
     */
    function resolveMarket(uint256 _marketId, uint256 _winningOption) 
        external 
        onlyOwner 
        marketExists(_marketId) 
    {
        Market storage market = markets[_marketId];
        require(block.timestamp >= market.endTime, "Market not yet ended");
        require(!market.resolved, "Market already resolved");
        require(_winningOption < market.options.length, "Invalid winning option");
        
        market.winningOption = _winningOption;
        market.resolved = true;
        
        emit MarketResolved(_marketId, _winningOption);
    }
    
    /**
     * @dev Claims winnings for a resolved market
     * @param _marketId The ID of the resolved market
     */
    function claimWinnings(uint256 _marketId) 
        external 
        marketExists(_marketId) 
    {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not resolved yet");
        
        uint256 userBet = market.userBets[msg.sender][market.winningOption];
        require(userBet > 0, "No winning bet found");
        
        // Calculate winnings: (user_bet / winning_pool) * total_pool
        uint256 winningPool = market.optionPools[market.winningOption];
        uint256 winnings = (userBet * market.totalPool) / winningPool;
        
        // Prevent double claiming
        market.userBets[msg.sender][market.winningOption] = 0;
        
        payable(msg.sender).transfer(winnings);
        
        emit WinningsClaimed(_marketId, msg.sender, winnings);
    }
    
    // View functions
    function getMarket(uint256 _marketId) 
        external 
        view 
        marketExists(_marketId) 
        returns (
            string memory question,
            string[] memory options,
            uint256 endTime,
            uint256 totalPool,
            bool resolved,
            uint256 winningOption
        ) 
    {
        Market storage market = markets[_marketId];
        return (
            market.question,
            market.options,
            market.endTime,
            market.totalPool,
            market.resolved,
            market.winningOption
        );
    }
    
    function getUserBet(uint256 _marketId, address _user, uint256 _option) 
        external 
        view 
        marketExists(_marketId) 
        returns (uint256) 
    {
        return markets[_marketId].userBets[_user][_option];
    }
    
    function getOptionPool(uint256 _marketId, uint256 _option) 
        external 
        view 
        marketExists(_marketId) 
        returns (uint256) 
    {
        return markets[_marketId].optionPools[_option];
    }
    
    function getUserMarkets(address _user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userMarkets[_user];
    }
}
