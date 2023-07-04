// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenDeployer {
    uint256 public deployedTokens;
    mapping(address => uint256) private userTokensCount;
    TokenInfo[] private userTokensArray;

    struct TokenInfo {
        address tokenAddress;
        address ownerAddress;
        string tokenName;
        string tokenSymbol;
        uint256 totalSupply;
    }

    function deployERC20Token(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public returns (address) {
        ERC20Token token = new ERC20Token(msg.sender, name, symbol, initialSupply);
        TokenInfo memory data = TokenInfo({
            tokenAddress: address(token),
            tokenName: name,
            tokenSymbol: symbol,
            totalSupply: initialSupply,
            ownerAddress: address(msg.sender)
        });
        userTokensArray.push(data);
        userTokensCount[address(msg.sender)] =
            userTokensCount[address(msg.sender)] +
            1;
        deployedTokens++;
        return address(token);
    }

    function GetUserTokens(address userAddress)
        public
        view
        returns (TokenInfo[] memory)
    {
        uint256 currentIndex = 0;
        TokenInfo[] memory itemsarray = new TokenInfo[](userTokensCount[userAddress]);
        for (uint256 i = 0; i < userTokensArray.length; i++) {
            TokenInfo memory currentItem = userTokensArray[i];
            if (currentItem.ownerAddress != userAddress) continue;
            itemsarray[currentIndex] = currentItem;
            currentIndex += 1;
        }
        return itemsarray;
    }
}

contract ERC20Token is ERC20 {
    constructor(
        address owner,
        string memory name,
        string memory symbol,
        uint256 totalSupply
    ) ERC20(name, symbol) {
        _mint(owner, totalSupply);
    }
}