// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Insurance Protocol
 * @dev A parametric insurance system for crop insurance based on weather conditions
 * @author Insurance Protocol Team
 */
contract Project {
    
    // Struct to represent an insurance policy
    struct Policy {
        uint256 policyId;
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startDate;
        uint256 endDate;
        string location;
        bool isActive;
        bool claimPaid;
    }
    
    // State variables
    mapping(uint256 => Policy) public policies;
    mapping(address => uint256[]) public userPolicies;
    uint256 public nextPolicyId = 1;
    uint256 public totalPremiumPool;
    address public owner;
    
    // Weather conditions that trigger payouts (simplified)
    mapping(string => uint256) public weatherData; // location => rainfall in mm
    uint256 public constant DROUGHT_THRESHOLD = 50; // Less than 50mm triggers payout
    
    // Events
    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, uint256 premium, uint256 coverage);
    event ClaimProcessed(uint256 indexed policyId, address indexed policyholder, uint256 payout);
    event WeatherDataUpdated(string location, uint256 rainfall);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validPolicy(uint256 _policyId) {
        require(_policyId < nextPolicyId && _policyId > 0, "Invalid policy ID");
        require(policies[_policyId].isActive, "Policy is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Purchase Insurance Policy
     * @param _coverageAmount The amount to be covered by insurance
     * @param _duration Duration of policy in days
     * @param _location Location for weather monitoring
     */
    function purchasePolicy(
        uint256 _coverageAmount,
        uint256 _duration,
        string memory _location
    ) external payable {
        require(msg.value > 0, "Premium must be greater than 0");
        require(_coverageAmount > 0, "Coverage amount must be greater than 0");
        require(_duration >= 30 && _duration <= 365, "Duration must be between 30-365 days");
        require(bytes(_location).length > 0, "Location cannot be empty");
        
        // Calculate premium as 5% of coverage amount (simplified)
        uint256 requiredPremium = (_coverageAmount * 5) / 100;
        require(msg.value >= requiredPremium, "Insufficient premium paid");
        
        // Create new policy
        Policy memory newPolicy = Policy({
            policyId: nextPolicyId,
            policyholder: msg.sender,
            premium: msg.value,
            coverageAmount: _coverageAmount,
            startDate: block.timestamp,
            endDate: block.timestamp + (_duration * 1 days),
            location: _location,
            isActive: true,
            claimPaid: false
        });
        
        policies[nextPolicyId] = newPolicy;
        userPolicies[msg.sender].push(nextPolicyId);
        totalPremiumPool += msg.value;
        
        emit PolicyCreated(nextPolicyId, msg.sender, msg.value, _coverageAmount);
        nextPolicyId++;
    }
    
    /**
     * @dev Core Function 2: Process Insurance Claim
     * @param _policyId The ID of the policy to claim
     */
    function processClaim(uint256 _policyId) external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        
        require(msg.sender == policy.policyholder, "Only policyholder can claim");
        require(block.timestamp >= policy.startDate, "Policy not yet active");
        require(block.timestamp <= policy.endDate, "Policy has expired");
        require(!policy.claimPaid, "Claim already paid");
        
        // Check weather conditions for payout trigger
        uint256 rainfall = weatherData[policy.location];
        require(rainfall < DROUGHT_THRESHOLD, "Weather conditions do not meet payout criteria");
        require(address(this).balance >= policy.coverageAmount, "Insufficient funds in contract");
        
        // Process payout
        policy.claimPaid = true;
        policy.isActive = false;
        
        // Transfer coverage amount to policyholder
        payable(policy.policyholder).transfer(policy.coverageAmount);
        
        emit ClaimProcessed(_policyId, policy.policyholder, policy.coverageAmount);
    }
    
    /**
     * @dev Core Function 3: Update Weather Data (Oracle simulation)
     * @param _location Location to update weather data for
     * @param _rainfall Rainfall amount in mm
     */
    function updateWeatherData(string memory _location, uint256 _rainfall) external onlyOwner {
        require(bytes(_location).length > 0, "Location cannot be empty");
        
        weatherData[_location] = _rainfall;
        emit WeatherDataUpdated(_location, _rainfall);
    }
    
    // Additional utility functions
    
    /**
     * @dev Get policy details
     * @param _policyId The ID of the policy
     */
    function getPolicyDetails(uint256 _policyId) external view returns (
        address policyholder,
        uint256 premium,
        uint256 coverageAmount,
        uint256 startDate,
        uint256 endDate,
        string memory location,
        bool isActive,
        bool claimPaid
    ) {
        require(_policyId < nextPolicyId && _policyId > 0, "Invalid policy ID");
        Policy memory policy = policies[_policyId];
        
        return (
            policy.policyholder,
            policy.premium,
            policy.coverageAmount,
            policy.startDate,
            policy.endDate,
            policy.location,
            policy.isActive,
            policy.claimPaid
        );
    }
    
    /**
     * @dev Get user's policy IDs
     * @param _user Address of the user
     */
    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Withdraw excess funds (only owner)
     */
    function withdrawExcess() external onlyOwner {
        require(address(this).balance > 0, "No funds to withdraw");
        payable(owner).transfer(address(this).balance);
    }
    
    /**
     * @dev Emergency function to deactivate a policy
     * @param _policyId Policy ID to deactivate
     */
    function deactivatePolicy(uint256 _policyId) external onlyOwner validPolicy(_policyId) {
        policies[_policyId].isActive = false;
    }
}
