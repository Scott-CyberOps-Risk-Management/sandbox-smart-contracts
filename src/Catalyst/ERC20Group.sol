pragma solidity 0.6.5;
pragma experimental ABIEncoderV2;

import "./ERC20SubToken.sol";
import "../contracts_common/src/Libraries/SafeMath.sol";
import "../contracts_common/src/Libraries/AddressUtils.sol";
import "../contracts_common/src/Libraries/ObjectLib32.sol";
import "../contracts_common/src/Libraries/BytesUtil.sol";

import "../contracts_common/src/BaseWithStorage/SuperOperators.sol";
import "../contracts_common/src/BaseWithStorage/MetaTransactionReceiver.sol";

contract ERC20Group is SuperOperators, MetaTransactionReceiver {
    /// @notice emitted when a new Token is added to the group.
    /// @param subToken the token added, its id will be its index in the array.
    event SubToken(ERC20SubToken subToken);

    /// @notice emitted when `owner` is allowing or disallowing `operator` to transfer tokens on its behalf.
    /// @param owner the address approving.
    /// @param operator the address being granted (or revoked) permission to transfer.
    /// @param approved whether the operator is granted transfer right or not.
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @dev emitted when the address responsible to mint new token or add new sub token is changed.
    /// @param newMinter address that is allowed to mint new tokens or add new sub tokens.
    event Minter(address newMinter);

    /// @dev return the current minter.
    /// @return minter address allowed to mint.
    function getMinter() external view returns (address minter) {
        return _minter;
    }

    /// @dev change the current minter.
    /// @param newMinter address of the new minter.
    function setMinter(address newMinter) external {
        require(msg.sender == _admin, "only admin allowed");
        _minter = newMinter;
        emit Minter(newMinter);
    }

    /// @dev mint more tokens of a specific subToken .
    /// @param to address receiving the tokens.
    /// @param id subToken id (also the index at which it was added).
    /// @param amount of token minted.
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external {
        require(msg.sender == _minter, "only minter allowed to mint");
        (uint256 bin, uint256 index) = id.getTokenBinIndex();
        _packedTokenBalance[to][bin] = _packedTokenBalance[to][bin].updateTokenBalance(index, amount, ObjectLib32.Operations.ADD);
        _packedSupplies[bin] = _packedSupplies[bin].updateTokenBalance(index, amount, ObjectLib32.Operations.ADD);
        _erc20s[id].emitTransferEvent(address(0), to, amount);
    }

    // TODO test
    /// @dev mint more tokens of a several subToken .
    /// @param to address receiving the tokens.
    /// @param ids subToken ids (also the index at which it was added).
    /// @param amounts for each token minted.
    function mintMultiple(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external {
        require(msg.sender == _minter, "only minter allowed to mint");
        require(ids.length == amounts.length, "inconsisten length");
        _mintMultiple(to, ids, amounts);
    }

    function _mintMultiple(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        uint256 lastBin = 2**256 - 1;
        uint256 bal = 0;
        uint256 supply = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            (uint256 bin, uint256 index) = ids[i].getTokenBinIndex();
            if (lastBin == 2**256 - 1) {
                lastBin = bin;
                bal = _packedTokenBalance[to][bin].updateTokenBalance(index, amounts[i], ObjectLib32.Operations.ADD);
                supply = _packedSupplies[bin].updateTokenBalance(index, amounts[i], ObjectLib32.Operations.ADD);
            } else {
                if (bin != lastBin) {
                    _packedTokenBalance[to][lastBin] = bal;
                    bal = _packedTokenBalance[to][bin];
                    _packedSupplies[lastBin] = supply;
                    supply = _packedSupplies[bin];
                    lastBin = bin;
                }
                bal = bal.updateTokenBalance(index, amounts[i], ObjectLib32.Operations.ADD);
                supply = supply.updateTokenBalance(index, amounts[i], ObjectLib32.Operations.ADD);
            }
            _erc20s[ids[i]].emitTransferEvent(address(0), to, amounts[i]);
        }
        if (lastBin != 2**256 - 1) {
            _packedTokenBalance[to][lastBin] = bal;
            _packedSupplies[lastBin] = supply;
        }
    }

    /// @dev add new subToken to the group
    /// @param subToken the address of the new ERC20 token added
    function addSubToken(ERC20SubToken subToken) external {
        require(msg.sender == _minter, "NOT_AUTHORIZED_ONLY_MINTER");
        _addSubToken(subToken);
    }

    /// @notice return the current total supply of a specific subToken.
    /// @param id subToken id.
    /// @return supply current total number of tokens.
    function supplyOf(uint256 id) external view returns (uint256 supply) {
        (uint256 bin, uint256 index) = id.getTokenBinIndex();
        return _packedSupplies[bin].getValueInBin(index);
    }

    /// @notice return the balance of a particular owner for a particular subToken.
    /// @param owner whose balance it is of.
    /// @param id subToken id.
    /// @return balance of the owner
    function balanceOf(address owner, uint256 id) public view returns (uint256 balance) {
        (uint256 bin, uint256 index) = id.getTokenBinIndex();
        return _packedTokenBalance[owner][bin].getValueInBin(index);
    }

    /// @notice return the balances of a list of owners / subTokens.
    /// @param owners list of addresses to which we want to know the balance.
    /// @param ids list of subTokens's addresses.
    /// @return balances list of balances for each request.
    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids) external view returns (uint256[] memory balances) {
        require(owners.length == ids.length, "Inconsistent array length between args");
        balances = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            balances[i] = balanceOf(owners[i], ids[i]);
        }
        return balances;
    }

    /// @notice transfer a number of subToken from one address to another.
    /// @param from owner to transfer from.
    /// @param to destination address that will receive the tokens.
    /// @param id subToken id.
    /// @param value amount of tokens to transfer.
    function singleTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value
    ) external {
        require(to != address(0), "INVALID_TO");
        ERC20SubToken erc20 = _erc20s[id];
        require(
            from == msg.sender ||
                msg.sender == address(erc20) ||
                _superOperators[msg.sender] ||
                _operatorsForAll[from][msg.sender] ||
                _metaTransactionContracts[msg.sender],
            "NOT_AUTHORIZED"
        );

        (uint256 bin, uint256 index) = id.getTokenBinIndex();
        _packedTokenBalance[from][bin] = _packedTokenBalance[from][bin].updateTokenBalance(index, value, ObjectLib32.Operations.SUB);
        _packedTokenBalance[to][bin] = _packedTokenBalance[to][bin].updateTokenBalance(index, value, ObjectLib32.Operations.ADD);
        erc20.emitTransferEvent(from, to, value);
    }

    /// @notice transfer a number of different subTokens from one address to another.
    /// @param from owner to transfer from.
    /// @param to destination address that will receive the tokens.
    /// @param ids list of subToken ids to transfer.
    /// @param values list of amount for eacg subTokens to transfer.
    function batchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values
    ) external {
        require(ids.length == values.length, "INVALID_ARGS_IDS_VALUES_LENGTH");
        require(to != address(0), "INVALID_TO");
        require(
            from == msg.sender || _superOperators[msg.sender] || _operatorsForAll[from][msg.sender] || _metaTransactionContracts[msg.sender],
            "NOT_AUTHORIZED"
        );

        uint256 bin = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        uint256 index;
        uint256 lastBin;
        uint256 balFrom;
        uint256 balTo;
        for (uint256 i = 0; i < ids.length; i++) {
            (bin, index) = ids[i].getTokenBinIndex();
            if (lastBin == 0) {
                lastBin = bin;
                balFrom = ObjectLib32.updateTokenBalance(_packedTokenBalance[from][bin], index, values[i], ObjectLib32.Operations.SUB);
                balTo = ObjectLib32.updateTokenBalance(_packedTokenBalance[to][bin], index, values[i], ObjectLib32.Operations.ADD);
            } else {
                if (bin != lastBin) {
                    _packedTokenBalance[from][lastBin] = balFrom;
                    _packedTokenBalance[to][lastBin] = balTo;
                    balFrom = _packedTokenBalance[from][bin];
                    balTo = _packedTokenBalance[to][bin];
                    lastBin = bin;
                }
                balFrom = balFrom.updateTokenBalance(index, values[i], ObjectLib32.Operations.SUB);
                balTo = balTo.updateTokenBalance(index, values[i], ObjectLib32.Operations.ADD);
            }
            ERC20SubToken erc20 = _erc20s[ids[i]];
            erc20.emitTransferEvent(from, to, values[i]);
        }
        if (bin != 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) {
            _packedTokenBalance[from][bin] = balFrom;
            _packedTokenBalance[to][bin] = balTo;
        }
    }

    /// @notice grant or revoke the ability for an address to transfer token on behalf of another address.
    /// @param sender address granting/revoking the approval.
    /// @param operator address being granted/revoked ability to transfer.
    /// @param approved whether the operator is revoked or approved.
    function setApprovalForAllFor(
        address sender,
        address operator,
        bool approved
    ) external {
        require(msg.sender == sender || _metaTransactionContracts[msg.sender] || _superOperators[msg.sender], "NOT_AUTHORIZED");
        _setApprovalForAll(sender, operator, approved);
    }

    /// @notice grant or revoke the ability for an address to transfer token on your behalf.
    /// @param operator address being granted/revoked ability to transfer.
    /// @param approved whether the operator is revoked or approved.
    function setApprovalForAll(address operator, bool approved) external {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice return whether an oeprator has the ability to transfer on behalf of another address.
    /// @param owner address who would have granted the rights.
    /// @param operator address being given the ability to transfer.
    /// @return isOperator whether the operator has approval rigths or not.
    function isApprovedForAll(address owner, address operator) external view returns (bool isOperator) {
        return _operatorsForAll[owner][operator] || _superOperators[operator];
    }

    /// @notice burn token for a specific owner and subToken.
    /// @param from fron which address the token are burned from.
    /// @param id subToken id.
    /// @param value amount of tokens to burn.
    function burnFor(
        address from,
        uint256 id,
        uint256 value
    ) external {
        require(
            from == msg.sender || _superOperators[msg.sender] || _operatorsForAll[from][msg.sender] || _metaTransactionContracts[msg.sender],
            "NOT_AUTHORIZED"
        );
        _burn(from, id, value);
    }

    /// @notice burn token for a specific subToken.
    /// @param id subToken id.
    /// @param value amount of tokens to burn.
    function burn(uint256 id, uint256 value) external {
        _burn(msg.sender, id, value);
    }

    /// @notice burn several subToken at once ro a specific owner.
    /// @param from fron which address the token are burned from.
    /// @param ids list of subToken id.
    /// @param value amount of tokens to burn for each
    function burnEachFor(
        address from,
        uint256[] calldata ids,
        uint256 value
    ) external {
        require(
            from == msg.sender || _superOperators[msg.sender] || _operatorsForAll[from][msg.sender] || _metaTransactionContracts[msg.sender],
            "NOT_AUTHORIZED"
        );
        _burnEach(from, ids, value);
    }

    // ///////////////// INTERNAL //////////////////////////

    function _burnEach(
        address from,
        uint256[] memory ids,
        uint256 value
    ) internal {
        uint256 lastBin = 2**256 - 1;
        uint256 bal = 0;
        uint256 supply = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            (uint256 bin, uint256 index) = ids[i].getTokenBinIndex();
            if (lastBin == 2**256 - 1) {
                lastBin = bin;
                bal = _packedTokenBalance[from][bin].updateTokenBalance(index, value, ObjectLib32.Operations.SUB);
                supply = _packedSupplies[bin].updateTokenBalance(index, value, ObjectLib32.Operations.SUB);
            } else {
                if (bin != lastBin) {
                    _packedTokenBalance[from][lastBin] = bal;
                    bal = _packedTokenBalance[from][bin];
                    _packedSupplies[lastBin] = supply;
                    supply = _packedSupplies[bin];
                    lastBin = bin;
                }
                bal = bal.updateTokenBalance(index, value, ObjectLib32.Operations.SUB);
                supply = supply.updateTokenBalance(index, value, ObjectLib32.Operations.SUB);
            }
            _erc20s[ids[i]].emitTransferEvent(from, address(0), value);
        }
        if (lastBin != 2**256 - 1) {
            _packedTokenBalance[from][lastBin] = bal;
            _packedSupplies[lastBin] = supply;
        }
    }

    function _burn(
        address from,
        uint256 id,
        uint256 value
    ) internal {
        ERC20SubToken erc20 = _erc20s[id];
        (uint256 bin, uint256 index) = id.getTokenBinIndex();
        _packedTokenBalance[from][bin] = ObjectLib32.updateTokenBalance(_packedTokenBalance[from][bin], index, value, ObjectLib32.Operations.SUB);
        _packedSupplies[bin] = ObjectLib32.updateTokenBalance(_packedSupplies[bin], index, value, ObjectLib32.Operations.SUB);
        erc20.emitTransferEvent(from, address(0), value);
    }

    function _addSubToken(ERC20SubToken subToken) internal {
        require(subToken.groupAddress() == address(this), "subToken fro different group");
        require(subToken.groupTokenId() == _erc20s.length, "id already taken");
        _erc20s.push(subToken);
        emit SubToken(subToken);
    }

    function _setApprovalForAll(
        address sender,
        address operator,
        bool approved
    ) internal {
        require(!_superOperators[operator], "super operator can't have their approvalForAll changed");
        _operatorsForAll[sender][operator] = approved;
        emit ApprovalForAll(sender, operator, approved);
    }

    // ///////////////// UTILITIES /////////////////////////
    using AddressUtils for address;
    using ObjectLib32 for ObjectLib32.Operations;
    using ObjectLib32 for uint256;
    using SafeMath for uint256;

    // ////////////////// DATA ///////////////////////////////
    mapping(uint256 => uint256) private _packedSupplies;
    mapping(address => mapping(uint256 => uint256)) private _packedTokenBalance;
    mapping(address => mapping(address => bool)) _operatorsForAll;
    ERC20SubToken[] _erc20s;
    address _minter;

    // ////////////// CONSTRUCTOR ////////////////////////////

    struct SubTokenData {
        string name;
        string symbol;
    }

    constructor(address admin, address minter) public {
        _admin = admin;
        _minter = minter;
    }
}