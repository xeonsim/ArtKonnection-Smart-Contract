// SPDX-License-Identifier: MIT

import "./KIP17Metadata.sol";
import "./ownership/Ownable.sol";
import "./math/SafeMath.sol";
import "./utils/String.sol";

pragma solidity ^0.5.0;
contract ArtKonnection is KIP17Metadata, Ownable {
    // using SafeMath for uint256;
    // To prevent bot attack, we record the last contract call block number

    struct Project {
        string name;
        string artist;
        string description;
        string website;
        string license;
        string projectBaseIpfsURI;
        uint256 invocations;
        uint256 maxInvocations;
        uint256 mintLimitPerBlock;           // Maximum purchase nft per person per block
        uint256 mintStartBlockNumber;  
        bool active;
        bool locked;
        bool WhitelistMintEnabled;
              // In blockchain, blocknumber is the standard of time.                 // 1 KLAY = 1000000000000000000
    }

    uint256 constant ONE_MILLION = 1_000_000;
    mapping(uint256 => Project) projects;

        //All financial functions are stripped from struct for visibility
    mapping(uint256 => address) public projectIdToArtistAddress;
    mapping(uint256 => uint256) public projectIdToPricePerTokenInPeb;
    mapping(uint256 => uint256) public projectIdToWhitelistPricePerTokenInPeb;
    mapping(uint256 => uint256) public projectIdToSecondaryMarketRoyaltyPercentage;

    uint256 public artKonnectionPercentage = 10;
    function updateArtKonnectionPercentage(uint256 _percentage) external onlyOwner{
        artKonnectionPercentage = _percentage;
    }

    mapping(uint256 => uint256) public tokenIdToProjectId;
    mapping(uint256 => uint256[]) internal projectIdToTokenIds;

    uint256 public nextProjectId;

    modifier onlyValidTokenId(uint256 _tokenId) {
        require(_exists(_tokenId), "Token ID does not exist");
        _;
    }

    modifier onlyUnlocked(uint256 _projectId) {
        require(!projects[_projectId].locked, "Only if unlocked");
        _;
    }


    modifier onlyArtistOrOwner(uint256 _projectId) {
        require(owner()==msg.sender || msg.sender == projectIdToArtistAddress[_projectId], "Only artist or whitelisted");
        _;
    }

    

    function tokenURI(uint256 _tokenId) external view onlyValidTokenId(_tokenId) returns (string memory) {
        string memory currentNotRevealedUri = projects[tokenIdToProjectId[_tokenId]].projectBaseIpfsURI;
        return bytes(currentNotRevealedUri).length > 0
            ? string(abi.encodePacked(currentNotRevealedUri, String.uint2str(_tokenId),".json"))
            : "";
    }

    function withdraw() external onlyOwner{
        (bool success,) = msg.sender.call.value(address(this).balance)("");
        require(success);
        // =============================================================================
    }

    function toggleProjectIsLocked(uint256 _projectId) public onlyArtistOrOwner(_projectId) onlyUnlocked(_projectId) {
        projects[_projectId].locked = true;
        projects[_projectId].active = false;
        projects[_projectId].WhitelistMintEnabled = false;
    }

    function toggleProjectIsActive(uint256 _projectId) public onlyArtistOrOwner(_projectId) onlyUnlocked(_projectId) {
        projects[_projectId].active = !projects[_projectId].active;
    }

    mapping(address => uint256[])  private artistAddressToProjectIds;

    function _deleteArtistProjectIdIndex(uint256 _projectId, address _addr) private  {
        for (uint256 i = 0; i < artistAddressToProjectIds[_addr].length; i++) {
            if (artistAddressToProjectIds[_addr][i] ==_projectId ) {
                artistAddressToProjectIds[msg.sender][i] = artistAddressToProjectIds[msg.sender][artistAddressToProjectIds[msg.sender].length-1];
                artistAddressToProjectIds[msg.sender].pop();
            }
        }
    }

    function updateProjectArtistAddress(uint256 _projectId, address _artistAddress) public onlyUnlocked(_projectId) onlyArtistOrOwner(_projectId) {
        require(projectIdToArtistAddress[_projectId]==msg.sender,"You are not artist of This project");
        projectIdToArtistAddress[_projectId] = _artistAddress;
        artistAddressToProjectIds[_artistAddress].push(_projectId);
        _deleteArtistProjectIdIndex(_projectId, msg.sender);   
    }

    function getArtistProjectIds(address _artistAddress) public view returns(uint256[] memory) {
        return artistAddressToProjectIds[_artistAddress];
    }

    function addProject(string memory _projectName, address _artistAddress, uint256 _pricePerTokenInPeb) public onlyOwner {
        uint256 projectId = nextProjectId;
        projectIdToArtistAddress[projectId] = _artistAddress;
        projects[projectId].name = _projectName;
        projectIdToPricePerTokenInPeb[projectId] = _pricePerTokenInPeb;
        projects[projectId].active=false;
        projects[projectId].locked=false;
        projects[projectId].invocations = 1;
        projects[projectId].maxInvocations = ONE_MILLION;
        projects[projectId].WhitelistMintEnabled = false;
        artistAddressToProjectIds[_artistAddress].push(nextProjectId);
        nextProjectId = nextProjectId.add(1);
    }

    function updateProjectPricePerTokenInPeb(uint256 _projectId, uint256 _pricePerTokenInPeb) onlyArtistOrOwner(_projectId) onlyUnlocked(_projectId) public {
        projectIdToPricePerTokenInPeb[_projectId] = _pricePerTokenInPeb;
    }

    function updateProjectWhitelistPrice(uint256 _projectId, uint256 _pricePerTokenInPeb) onlyArtistOrOwner(_projectId) onlyUnlocked(_projectId) public {
        projectIdToWhitelistPricePerTokenInPeb[_projectId]= _pricePerTokenInPeb;
    }

    function updateMintLimitPerBlock(uint256 _projectId, uint256 _limit) onlyArtistOrOwner(_projectId) onlyUnlocked(_projectId) public {
        projects[_projectId].mintLimitPerBlock = _limit;
    }

    function updateMintStartBlockNumber(uint256 _projectId, uint256 _blockNumber) onlyArtistOrOwner(_projectId) onlyUnlocked(_projectId) public {
        projects[_projectId].mintStartBlockNumber = _blockNumber;
    }

    function updateProjectName(uint256 _projectId, string memory _projectName) onlyUnlocked(_projectId) onlyArtistOrOwner(_projectId) public {
        projects[_projectId].name = _projectName;
    }

    function updateProjectArtistName(uint256 _projectId, string memory _projectArtistName) onlyUnlocked(_projectId) onlyArtistOrOwner(_projectId) public {
        projects[_projectId].artist = _projectArtistName;
    }
    function updateProjectSecondaryMarketRoyaltyPercentage(uint256 _projectId, uint256 _secondMarketRoyalty) onlyUnlocked(_projectId) onlyArtistOrOwner(_projectId) public {
        require(_secondMarketRoyalty <= 30, "Max of 30%");
        projectIdToSecondaryMarketRoyaltyPercentage[_projectId] = _secondMarketRoyalty;
    }

    function updateProjectDescription(uint256 _projectId, string memory _projectDescription) onlyUnlocked(_projectId) onlyArtistOrOwner(_projectId) public {
        projects[_projectId].description = _projectDescription;
    }

    function updateProjectWebsite(uint256 _projectId, string memory _projectWebsite) onlyUnlocked(_projectId) onlyArtistOrOwner(_projectId) public {
        projects[_projectId].website = _projectWebsite;
    }

    function updateProjectLicense(uint256 _projectId, string memory _projectLicense) onlyUnlocked(_projectId) onlyArtistOrOwner(_projectId) public {
        projects[_projectId].license = _projectLicense;
    }

    function updateProjectMaxInvocations(uint256 _projectId, uint256 _maxInvocations) onlyArtistOrOwner(_projectId) onlyUnlocked(_projectId) public {
        require((!projects[_projectId].locked || _maxInvocations<projects[_projectId].maxInvocations), "Only if unlocked");
        require(_maxInvocations > projects[_projectId].invocations, "You must set max invocations greater than current invocations");
        require(_maxInvocations <= ONE_MILLION, "Cannot exceed 1,000,000");
        projects[_projectId].maxInvocations = _maxInvocations;
    }
    function updateProjectBaseIpfsURI(uint256 _projectId, string memory _projectBaseIpfsURI) onlyUnlocked(_projectId) onlyArtistOrOwner(_projectId) public {
        projects[_projectId].projectBaseIpfsURI = _projectBaseIpfsURI;
    }

    function projectDetails(uint256 _projectId) view public returns (string memory projectName, string memory artist, string memory description, string memory website, string memory license) {
        projectName = projects[_projectId].name;
        artist = projects[_projectId].artist;
        description = projects[_projectId].description;
        website = projects[_projectId].website;
        license = projects[_projectId].license;
    }
    function projectTokenInfo(uint256 _projectId) view public returns (address artistAddress, uint256 pricePerTokenInPeb,uint256 whitelistPricePerTokenInPeb, uint256 invocations, uint256 maxInvocations, bool active, bool whitelistMintActive) {
        artistAddress = projectIdToArtistAddress[_projectId];
        pricePerTokenInPeb = projectIdToPricePerTokenInPeb[_projectId];
        whitelistPricePerTokenInPeb = projectIdToWhitelistPricePerTokenInPeb[_projectId];
        invocations = projects[_projectId].invocations;
        maxInvocations = projects[_projectId].maxInvocations;
        active = projects[_projectId].active;
        whitelistMintActive = projects[_projectId].WhitelistMintEnabled;
    }

    function projectURIInfo(uint256 _projectId) public view returns (string memory projectBaseIpfsURI) {
        projectBaseIpfsURI = projects[_projectId].projectBaseIpfsURI;
    }
    function projectShowAllTokens(uint _projectId) public view returns (uint256[] memory){
        return projectIdToTokenIds[_projectId];
    }
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        return _tokensOfOwner(owner);
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view  returns (address, uint256) {

        uint256 projectRoyaltyPercentage = projectIdToSecondaryMarketRoyaltyPercentage[tokenIdToProjectId[_tokenId]];

        uint256 royaltyAmount = (_salePrice * projectRoyaltyPercentage / 100);

        return (projectIdToArtistAddress[tokenIdToProjectId[_tokenId]], royaltyAmount);
    }

}
