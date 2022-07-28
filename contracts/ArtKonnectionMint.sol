pragma solidity ^0.5.0;

import "./ArtKonnection.sol";


contract ArtKonnectionMint is  ArtKonnection {

    mapping (address => uint256) private _lastCallBlockNumber;
    uint256 private _antibotInterval;

    function updateAntibotInterval(uint256 _interval) external onlyOwner {
        _antibotInterval = _interval;
    }

    event Mint(
        address indexed _to,
        uint256 indexed _tokenId,
        uint256 indexed _projectId
    );

    function mintingInformation(uint256 _projectId) public view returns (uint256 antibotInterval, uint256 mintLimitPerBlock, uint256 mintStartBlockNumber){
      antibotInterval=_antibotInterval;
      mintLimitPerBlock=projects[_projectId].mintLimitPerBlock;
      mintStartBlockNumber=projects[_projectId].mintStartBlockNumber;
    }

    function _mintToken(address _to, uint256 _projectId) internal returns (uint256 _tokenId) {

        uint256 tokenIdToBe = (_projectId * ONE_MILLION) + projects[_projectId].invocations;

        projects[_projectId].invocations = projects[_projectId].invocations.add(1);

        _mint(_to, tokenIdToBe);

        tokenIdToProjectId[tokenIdToBe] = _projectId;
        projectIdToTokenIds[_projectId].push(tokenIdToBe);

        emit Mint(_to, tokenIdToBe, _projectId);

        return tokenIdToBe;
    }

    function publicMint(uint256 requestedCount, uint256 _projectId) external payable onlyUnlocked(_projectId){
        require(projects[_projectId].active, "The public sale is not enabled!");
        require(_lastCallBlockNumber[msg.sender].add(_antibotInterval) < block.number, "Bot is not allowed");
        require(block.number >= projects[_projectId].mintStartBlockNumber, "Not yet started");
        require(requestedCount > 0 && requestedCount <= projects[_projectId].mintLimitPerBlock, "Too many requests or zero request");
        require(msg.value == projectIdToPricePerTokenInPeb[_projectId].mul(requestedCount), "Not enough Klay");
        require(projects[_projectId].invocations.add(requestedCount) <= projects[_projectId].maxInvocations + 1, "Exceed max amount");
        (bool success,) = projectIdToArtistAddress[_projectId].call.value(msg.value*(100-artKonnectionPercentage)/100)("");
        require(success,"failed to mint");


        for(uint256 i = 0; i < requestedCount; i++) {
            _mintToken(msg.sender, _projectId);
        }
        
        _lastCallBlockNumber[msg.sender] = block.number;
    }

    //Whitelist Mint
    mapping(address => uint256[]) internal whitelistClaimedProject;
    mapping(address => bool) public whitelistAddress;

    function _checkClaimedProject(uint256 _projectId, address _whitelistAddress) internal view returns (bool) {
        for (uint256 i = 0; i < whitelistClaimedProject[_whitelistAddress].length; i++) {
            if (whitelistClaimedProject[_whitelistAddress][i] ==_projectId ) {
                return false;
            }
        }
        return true;
    }

    function addWhitelist(address _whitelistAddress) external onlyOwner {
        whitelistAddress[_whitelistAddress]=true;
    }

    function removeWhitelist(address _whitelistAddress) external onlyOwner {
        whitelistAddress[_whitelistAddress]=false;
    }

    function toggleWhitelistMintEnabled(uint256 _projectId) external onlyArtistOrOwner(_projectId) onlyUnlocked(_projectId) {
        projects[_projectId].WhitelistMintEnabled = !projects[_projectId].WhitelistMintEnabled;
    }

    function whitelistMint(uint256 requestedCount, uint256 _projectId) external payable onlyUnlocked(_projectId) {
        require(projects[_projectId].WhitelistMintEnabled, "The whitelist sale is not enabled!");
        require(msg.value == projectIdToWhitelistPricePerTokenInPeb[_projectId].mul(requestedCount), "Not enough Klay");
        require(whitelistAddress[msg.sender],"sender is not on Whitelist");
        require(_checkClaimedProject(_projectId, msg.sender), "Address already claimed!");
        require(requestedCount > 0 && requestedCount <= projects[_projectId].mintLimitPerBlock, "Too many requests or zero request");
        (bool success,) = projectIdToArtistAddress[_projectId].call.value(msg.value*(100-artKonnectionPercentage)/100)("");
        require(success,"whitelist mint failed");
        
        for(uint256 i = 0; i < requestedCount; i++) {
            _mintToken(msg.sender, _projectId );
        }
        
        whitelistClaimedProject[msg.sender].push(_projectId);
    }

    //Airdrop Mint
    function airDropMint(address user, uint256 requestedCount, uint256 _projectId) external onlyOwner onlyUnlocked(_projectId){
        require(requestedCount > 0, "zero request");
        for(uint256 i = 0; i < requestedCount; i++) {
            _mintToken(user, _projectId );
        }
    }
}