// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract MobiFiStakingToken is ERC20, ERC20Burnable, Ownable {
    mapping(address => bool) public Minter;
    uint256 constant MaxSupply = 150e24;
    using SafeMath for uint256;
    string public symbol;
    string public  name;
    uint8 public decimals;

    constructor(address _masterAddress, uint256 _preMintAmount) public
    {
        symbol = "MOFI";
        name = "MobiFiSToken";
        decimals = 18;

        _mint(_masterAddress, _preMintAmount);
    }

    function AddMinter(address _minter) public onlyOwner {
        Minter[_minter] = true;
    }

    function RemoveMinter(address _minter) public onlyOwner {
        Minter[_minter] = false;
    }

    modifier onlyMinter() {
        require(Minter[msg.sender]);
        _;
    }

    function mint(address account, uint256 amount) public onlyMinter {
        uint256 TotalSupply = totalSupply();
        if (TotalSupply.add(amount) > MaxSupply) {
            _mint(account, MaxSupply.sub(TotalSupply));
        } else {
            _mint(account, amount);
        }
    }

    function burn(address account, uint256 amount) public onlyMinter {
        _burn(account, amount);
    }
}