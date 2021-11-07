// EverOwn Wrapper contract exmaple

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// If interfaces are needed add them here

// IERC20/IBEP20 standard interface.
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * Any contract methods that are required
 */
interface IMyContract {
    // Any other/different contract wrapper methods if ownership transfer is not via transferOwnership
    function transferOwnership(address payable _address) external;
    // Any contract methods required to be exposed to authorized users triggerBuyback is an example
    function triggerBuyback(uint256 amount) external returns (uint256);
}

contract Ownable is Context {
    address private _owner;
    address private _buybackOwner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    
    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );

        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function owner() public view returns (address) {
        return _owner;
    }
}

// Allows for contract ownership along with multi-address authorization bypass
abstract contract EverOwnProxy is Ownable {
    mapping (address => bool) private authorizations;
    address[] public allAuthorizations;

    event AuthorizationAdded(address _address);
    event AuthorizationRemoved(address _address);

    // Function modifier to require caller to be authorized
    modifier onlyAuthorized() {
        require(isAuthorized(msg.sender), "Not Authorized");
        _;
    }

    constructor(address _owner) {
        authorize(_owner);
    }

    // Remove address authorization. Owner only
    function unauthorize(address _address) external onlyOwner {
        require(authorizations[_address], "_address is not currently authorized");

        authorizations[_address] = false;

        for (uint256 i = 0; i < allAuthorizations.length; i++) {
            if (allAuthorizations[i] == _address) {
                allAuthorizations[i] = allAuthorizations[allAuthorizations.length - 1];
                allAuthorizations.pop();
                break;
            }
        }

        emit AuthorizationRemoved(_address);
    }

    // Authorize address. Owner only
    function authorize(address _address) public onlyOwner {
        require(authorizations[_address], "_address is already authorized");

        authorizations[_address] = true;
        allAuthorizations.push(_address);

        emit AuthorizationAdded(_address);
    }

    function allAuthorizationsLength() external view returns (uint) {
        return allAuthorizations.length;
    }

    // Return address' authorization status
    function isAuthorized(address _address) public view returns (bool) {
        return authorizations[_address];
    }
}

// *** Rename this to your proxy wrapper contract
contract MyContractOwn is EverOwnProxy {
    // *** Rename to be an ownership proxy for your token e.g. xxxxOWN
    string private _name = "MyContractOwn";
    string private _symbol = "MyContracOWN";

    IMyContract public token;

    constructor (address _token) EverOwnProxy(_msgSender()) {
        token = IMyContract(payable(_token));
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    // *** Example function that remains exposed to authorized users
    function triggerBuyback(uint256 amount) external onlyAuthorized {
        token.triggerBuyback(amount);
    }

    // *** Releasing the ownership from the wrapper contract back to owner
    function releaseOwnership() public onlyOwner {
        // ****
        // If your contract uses a different ownership technique and that's why you are wrapping
        // change the body of this function to match that
        // ***
        token.transferOwnership(_msgSender());
    }

    // Function to release ETH trapped in wrapper, can be released when ownership returned
    function releaseTrappedETH(address payable toAddress) external onlyOwner {
        require(toAddress != address(0), "toAddress can not be a zero address");
        toAddress.transfer(address(this).balance);
    }

    // Function to release tokens trapped in wrapper, can be released when ownership returned
    function releaseTrappedTokens(address tokenAddress, address toAddress) external onlyOwner {
        require(tokenAddress != address(0), "tokenAddress can not be a zero address");
        require(toAddress != address(0), "toAddress can not be a zero address");
        require(IERC20(tokenAddress).balanceOf(address(this)) > 0, "Balance is zero");
        IERC20(tokenAddress).transfer(toAddress, IERC20(tokenAddress).balanceOf(address(this)));
    }

    // To recieve ETH
    receive() external payable {}

    // Fallback function to receive ETH when msg.data is not empty
    fallback() external payable {}
}