// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract ERC721StakingV2 is  ReentrancyGuard {
    using SafeERC20 for IERC20;

  
    IERC20 public immutable rewardsToken;
    IERC721 public immutable nftCollection;

    constructor(IERC721 _nftCollection, IERC20 _rewardsToken) {
        nftCollection = _nftCollection;
        rewardsToken = _rewardsToken;
    }

    struct StakedToken {
      address staker;
      uint256 tokenId;
    }

    struct Staker {
        uint256 amountStaked;
        StakedToken[] stakedTokens;
        uint256 timeOfLastUpdate;
        uint256 unclaimedRewards;
    }

    uint256 private rewardsPerHour = 100000;

    mapping(address => Staker) public stakers;

    mapping(uint256 => address) public stakerAddress;

   
    function stake(uint256  _tokenId) external  nonReentrant {

        if (stakers[msg.sender].amountStaked > 0) {
            uint256 rewards = calculateRewards(msg.sender);
            stakers[msg.sender].unclaimedRewards += rewards;
         } 

         require(nftCollection.ownerOf(_tokenId) == msg.sender,"You don't own this NFT");

         StakedToken memory stakedToken = StakedToken(msg.sender,_tokenId);

         stakers[msg.sender].stakedTokens.push(stakedToken);

         stakers[msg.sender].amountStaked++;

         stakerAddress[_tokenId] = msg.sender;

         stakers[msg.sender].timeOfLastUpdate = block.timestamp;

         nftCollection.transferFrom(msg.sender,address(this),_tokenId);
        
    }

   
    function withdraw(uint256  _tokenId) external nonReentrant {

        require(stakers[msg.sender].amountStaked > 0, "You have no tokens staked");
        require(stakerAddress[_tokenId] == msg.sender, "You don't own this NFT");
        
        uint256 rewards = calculateRewards(msg.sender);
        stakers[msg.sender].unclaimedRewards += rewards;

        uint256 index = 0;
        for(uint256 i = 0 ; i< stakers[msg.sender].stakedTokens.length; i++) {
            if(stakers[msg.sender].stakedTokens[i].tokenId == _tokenId){
                index = i;
                break;
            }
        }

        stakers[msg.sender].stakedTokens[index].staker = address(0);

        stakers[msg.sender].amountStaked--;

        stakerAddress[_tokenId] = address(0);

        nftCollection.transferFrom(address(this),msg.sender,_tokenId);

        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
    }

   
    function claimRewards() external {
       uint256 rewards = calculateRewards(msg.sender) +
            stakers[msg.sender].unclaimedRewards;

        require(rewards > 0 , "You have no rewards to claim");

        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        stakers[msg.sender].unclaimedRewards = 0;

        rewardsToken.safeTransfer(msg.sender, rewards);
    }
   
    function availableRewards(address _user) internal view returns (uint256 _rewards) {
        uint256 rewards = calculateRewards(_user) + stakers[_user].unclaimedRewards;
        return rewards;
    }

  
    function calculateRewards(address _staker) internal view returns (uint256 _rewards) {
        return (
            ((((block.timestamp - stakers[_staker].timeOfLastUpdate) * 
                    stakers[_staker].amountStaked)
            ) * rewardsPerHour) / 3600  );
    }

    
    function getStakedTokens(address _user)
        public
        view
        returns (StakedToken[] memory )
    {
       if(stakers[_user].amountStaked >0) {
        StakedToken[] memory _stakedTokens = new StakedToken[](stakers[_user].amountStaked);
        uint256 _index = 0;

        for(uint256 j = 0; j < stakers[_user].stakedTokens.length; j++){
            if(stakers[_user].stakedTokens[j].staker != (address(0))) {
                _stakedTokens[_index] = stakers[_user].stakedTokens[j];
                _index++;
            }
        }

        return _stakedTokens;
       }
       else {
        return new StakedToken[](0);
       }
    }

   

}