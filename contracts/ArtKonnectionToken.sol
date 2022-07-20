pragma solidity ^0.5.0;

import "./KIP17Full.sol";

contract ArtKonnectionToken is KIP17Full {
    constructor(string memory name, string memory symbol)
        public
        KIP17Full(name, symbol)
    {}
}
