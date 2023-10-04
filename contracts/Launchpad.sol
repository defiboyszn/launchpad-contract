// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Crowdsale is Context, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // The token being sold
    IERC20 private _token;

    // Address where funds are collected
    address payable private _wallet;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    uint256 private _rate;

    // Amount of wei raised
    uint256 private _weiRaised;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );

    /**
     * @param rate_ Number of token units a buyer gets per wei
     * @dev The rate is the conversion between wei and the smallest and indivisible
     * token unit. So, if you are using a rate of 1 with a ERC20Detailed token
     * with 3 decimals called TOK, 1 wei will give you 1 unit, or 0.001 TOK.
     * @param wallet_ Address where collected funds will be forwarded to
     * @param token_ Address of the token being sold
     */
    constructor(
        uint256 rate_,
        address payable wallet_,
        IERC20 token_
    ) {
        require(rate_ > 0, "Crowdsale: rate is 0");
        require(wallet_ != address(0), "Crowdsale: wallet is the zero address");
        require(
            address(token_) != address(0),
            "Crowdsale: token is the zero address"
        );

        _rate = rate_;
        _wallet = wallet_;
        _token = token_;
    }

    /**
     * @dev fallback function **DO NOT OVERRIDE**
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    receive() external payable {
        buyTokens(_msgSender());
    }

    /**
     * @return the token being sold.
     */
    function token() public view returns (IERC20) {
        return _token;
    }

    /**
     * @return the address where funds are collected.
     */
    function wallet() public view returns (address payable) {
        return _wallet;
    }

    /**
     * @return the number of token units a buyer gets per wei.
     */
    function rate() public view virtual returns (uint256) {
        return _rate;
    }

    /**
     * @return the amount of wei raised.
     */
    function weiRaised() public view returns (uint256) {
        return _weiRaised;
    }

    /**
     * @dev low level token purchase **DO NOT OVERRIDE**
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param beneficiary Recipient of the token purchase
     */
    function buyTokens(address beneficiary) public payable nonReentrant {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        _weiRaised = _weiRaised.add(weiAmount);

        _processPurchase(beneficiary, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);

        _updatePurchasingState(beneficiary, weiAmount);

        _forwardFunds();
        _postValidatePurchase(beneficiary, weiAmount);
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * Use `super` in contracts that inherit from Crowdsale to extend their validations.
     * Example from CappedCrowdsale.sol's _preValidatePurchase method:
     *     super._preValidatePurchase(beneficiary, weiAmount);
     *     require(weiRaised().add(weiAmount) <= cap);
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        virtual
    {
        require(
            beneficiary != address(0),
            "Crowdsale: beneficiary is the zero address"
        );
        require(weiAmount != 0, "Crowdsale: weiAmount is 0");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid
     * conditions are not met.
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _postValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        view
    {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends
     * its tokens.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount)
        internal
        virtual
    {
        _token.safeTransfer(beneficiary, tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
     * tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
        virtual
    {
        _deliverTokens(beneficiary, tokenAmount);
    }

    /**
     * @dev Override for extensions that require an internal state to check for validity (current user contributions,
     * etc.)
     * @param beneficiary Address receiving the tokens
     * @param weiAmount Value in wei involved in the purchase
     */
    function _updatePurchasingState(address beneficiary, uint256 weiAmount)
        internal
        virtual
    {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount)
        internal
        view
        virtual
        returns (uint256)
    {
        return weiAmount.mul(_rate);
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal virtual {
        _wallet.transfer(msg.value);
    }
}

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title CappedCrowdsale
 * @dev Crowdsale with a limit for total contributions.
 */
abstract contract CappedCrowdsale is Crowdsale {
    using SafeMath for uint256;

    uint256 private _cap;

    /**
     * @dev Constructor, takes maximum amount of wei accepted in the crowdsale.
     * @param cap_ Max amount of wei to be contributed
     */
    constructor(uint256 cap_) {
        require(cap_ > 0, "CappedCrowdsale: cap is 0");
        _cap = cap_;
    }

    /**
     * @return the cap of the crowdsale.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    /**
     * @dev Checks whether the cap has been reached.
     * @return Whether the cap was reached
     */
    function capReached() public view returns (bool) {
        return weiRaised() >= _cap;
    }

    /**
     * @dev Extend parent behavior requiring purchase to respect the funding cap.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        virtual
        override
    {
        super._preValidatePurchase(beneficiary, weiAmount);
        require(
            weiRaised().add(weiAmount) <= _cap,
            "CappedCrowdsale: cap exceeded"
        );
    }
}

import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev A Secondary contract can only be used by its primary account (the one that created it).
 */
contract Secondary is Context {
    address private _primary;

    /**
     * @dev Emitted when the primary contract changes.
     */
    event PrimaryTransferred(address recipient);

    /**
     * @dev Sets the primary account to the one that is creating the Secondary contract.
     */
    constructor() {
        address msgSender = _msgSender();
        _primary = msgSender;
        emit PrimaryTransferred(msgSender);
    }

    /**
     * @dev Reverts if called from any account other than the primary.
     */
    modifier onlyPrimary() {
        require(
            _msgSender() == _primary,
            "Secondary: caller is not the primary account"
        );
        _;
    }

    /**
     * @return the address of the primary.
     */
    function primary() public view returns (address) {
        return _primary;
    }

    /**
     * @dev Transfers contract to a new primary.
     * @param recipient The address of new primary.
     */
    function transferPrimary(address recipient) public onlyPrimary {
        require(
            recipient != address(0),
            "Secondary: new primary is the zero address"
        );
        _primary = recipient;
        emit PrimaryTransferred(recipient);
    }
}

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title TimedCrowdsale
 * @dev Crowdsale accepting contributions only within a time frame.
 */
abstract contract TimedCrowdsale is Crowdsale {
    using SafeMath for uint256;

    uint256 private _openingTime;
    uint256 private _closingTime;

    /**
     * Event for crowdsale extending
     * @param newClosingTime new closing time
     * @param prevClosingTime old closing time
     */
    event TimedCrowdsaleExtended(
        uint256 prevClosingTime,
        uint256 newClosingTime
    );

    /**
     * @dev Reverts if not in crowdsale time range.
     */
    modifier onlyWhileOpen() {
        require(isOpen(), "TimedCrowdsale: not open");
        _;
    }

    /**
     * @dev Constructor, takes crowdsale opening and closing times.
     * @param openingTime_ Crowdsale opening time
     * @param closingTime_ Crowdsale closing time
     */
    constructor(uint256 openingTime_, uint256 closingTime_) {
        // solhint-disable-next-line not-rely-on-time
        require(
            openingTime_ >= block.timestamp,
            "TimedCrowdsale: opening time is before current time"
        );
        // solhint-disable-next-line max-line-length
        require(
            closingTime_ > openingTime_,
            "TimedCrowdsale: opening time is not before closing time"
        );

        _openingTime = openingTime_;
        _closingTime = closingTime_;
    }

    /**
     * @return the crowdsale opening time.
     */
    function openingTime() public view returns (uint256) {
        return _openingTime;
    }

    /**
     * @return the crowdsale closing time.
     */
    function closingTime() public view returns (uint256) {
        return _closingTime;
    }

    /**
     * @return true if the crowdsale is open, false otherwise.
     */
    function isOpen() public view returns (bool) {
        // solhint-disable-next-line not-rely-on-time
        return
            block.timestamp >= _openingTime && block.timestamp <= _closingTime;
    }

    /**
     * @dev Checks whether the period in which the crowdsale is open has already elapsed.
     * @return Whether crowdsale period has elapsed
     */
    function hasClosed() public view returns (bool) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp > _closingTime;
    }

    /**
     * @dev Extend parent behavior requiring to be within contributing period.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        virtual
        override
        onlyWhileOpen
    {
        super._preValidatePurchase(beneficiary, weiAmount);
    }

    /**
     * @dev Extend crowdsale.
     * @param newClosingTime Crowdsale closing time
     */
    function _extendTime(uint256 newClosingTime) internal {
        require(!hasClosed(), "TimedCrowdsale: already closed");
        // solhint-disable-next-line max-line-length
        require(
            newClosingTime > _closingTime,
            "TimedCrowdsale: new closing time is before current closing time"
        );

        emit TimedCrowdsaleExtended(_closingTime, newClosingTime);
        _closingTime = newClosingTime;
    }
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title PostDeliveryCrowdsale
 * @dev Crowdsale that locks tokens from withdrawal until it ends.
 */
abstract contract PostDeliveryCrowdsale is TimedCrowdsale {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;
    __unstable__TokenVault private _vault;

    constructor() {
        _vault = new __unstable__TokenVault();
    }

    /**
     * @dev Withdraw tokens only after crowdsale ends.
     * @param beneficiary Whose tokens will be withdrawn.
     */
    function withdrawTokens(address beneficiary) public virtual {
        require(hasClosed(), "PostDeliveryCrowdsale: not closed");
        uint256 amount = _balances[beneficiary];
        require(
            amount > 0,
            "PostDeliveryCrowdsale: beneficiary is not due any tokens"
        );

        _balances[beneficiary] = 0;
        _vault.transfer(token(), beneficiary, amount);
    }

    /**
     * @return the balance of an account.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Overrides parent by storing due balances, and delivering tokens to the vault instead of the end user. This
     * ensures that the tokens will be available by the time they are withdrawn (which may not be the case if
     * `_deliverTokens` was called later).
     * @param beneficiary Token purchaser
     * @param tokenAmount Amount of tokens purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
        virtual
        override
    {
        _balances[beneficiary] = _balances[beneficiary].add(tokenAmount);
        _deliverTokens(address(_vault), tokenAmount);
    }
}

/**
 * @title __unstable__TokenVault
 * @dev Similar to an Escrow for tokens, this contract allows its primary account to spend its tokens as it sees fit.
 * This contract is an internal helper for PostDeliveryCrowdsale, and should not be used outside of this context.
 */
// solhint-disable-next-line contract-name-camelcase
contract __unstable__TokenVault is Secondary {
    function transfer(
        IERC20 token,
        address to,
        uint256 amount
    ) public onlyPrimary {
        token.transfer(to, amount);
    }
}

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title FinalizableCrowdsale
 * @dev Extension of TimedCrowdsale with a one-off finalization action, where one
 * can do extra work after finishing.
 */
abstract contract FinalizableCrowdsale is TimedCrowdsale {
    using SafeMath for uint256;

    bool private _finalized;

    event CrowdsaleFinalized();

    constructor() {
        _finalized = false;
    }

    /**
     * @return true if the crowdsale is finalized, false otherwise.
     */
    function finalized() public view returns (bool) {
        return _finalized;
    }

    /**
     * @dev Must be called after crowdsale ends, to do some extra finalization
     * work. Calls the contract's finalization function.
     */
    function finalize() public {
        require(!_finalized, "FinalizableCrowdsale: already finalized");
        require(hasClosed(), "FinalizableCrowdsale: not closed");

        _finalized = true;

        _finalization();
        emit CrowdsaleFinalized();
    }

    /**
     * @dev Can be overridden to add finalization logic. The overriding function
     * should call super._finalization() to ensure the chain of finalization is
     * executed entirely.
     */
    function _finalization() internal virtual {
        // solhint-disable-previous-line no-empty-blocks
    }
}

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/escrow/RefundEscrow.sol";

/**
 * @title RefundableCrowdsale
 * @dev Extension of `FinalizableCrowdsale` contract that adds a funding goal, and the possibility of users
 * getting a refund if goal is not met.
 *
 * Deprecated, use `RefundablePostDeliveryCrowdsale` instead. Note that if you allow tokens to be traded before the goal
 * is met, then an attack is possible in which the attacker purchases tokens from the crowdsale and when they sees that
 * the goal is unlikely to be met, they sell their tokens (possibly at a discount). The attacker will be refunded when
 * the crowdsale is finalized, and the users that purchased from them will be left with worthless tokens.
 */
abstract contract RefundableCrowdsale is Context, FinalizableCrowdsale {
    using SafeMath for uint256;

    // minimum amount of funds to be raised in weis
    uint256 private _goal;

    // refund escrow used to hold funds while crowdsale is running
    RefundEscrow private _escrow;

    /**
     * @dev Constructor, creates RefundEscrow.
     * @param goal_ Funding goal
     */
    constructor(uint256 goal_) {
        require(goal_ > 0, "RefundableCrowdsale: goal is 0");
        _escrow = new RefundEscrow(wallet());
        _goal = goal_;
    }

    /**
     * @return minimum amount of funds to be raised in wei.
     */
    function goal() public view returns (uint256) {
        return _goal;
    }

    /**
     * @dev Investors can claim refunds here if crowdsale is unsuccessful.
     * @param refundee Whose refund will be claimed.
     */
    function claimRefund(address payable refundee) public {
        require(finalized(), "RefundableCrowdsale: not finalized");
        require(!goalReached(), "RefundableCrowdsale: goal reached");

        _escrow.withdraw(refundee);
    }

    /**
     * @dev Checks whether funding goal was reached.
     * @return Whether funding goal was reached
     */
    function goalReached() public view returns (bool) {
        return weiRaised() >= _goal;
    }

    /**
     * @dev Escrow finalization task, called when finalize() is called.
     */
    function _finalization() internal virtual override {
        if (goalReached()) {
            _escrow.close();
            _escrow.beneficiaryWithdraw();
        } else {
            _escrow.enableRefunds();
        }

        super._finalization();
    }

    /**
     * @dev Overrides Crowdsale fund forwarding, sending funds to escrow.
     */
    function _forwardFunds() internal virtual override {
        _escrow.deposit{value: msg.value}(_msgSender());
    }
}

/**
 * @title RefundablePostDeliveryCrowdsale
 * @dev Extension of RefundableCrowdsale contract that only delivers the tokens
 * once the crowdsale has closed and the goal met, preventing refunds to be issued
 * to token holders.
 */
abstract contract RefundablePostDeliveryCrowdsale is
    RefundableCrowdsale,
    PostDeliveryCrowdsale
{
    constructor(uint256 goal_) RefundableCrowdsale(goal_) {
        //
    }

    function withdrawTokens(address beneficiary) public override {
        require(finalized(), "RefundablePostDeliveryCrowdsale: not finalized");
        require(
            goalReached(),
            "RefundablePostDeliveryCrowdsale: goal not reached"
        );

        super.withdrawTokens(beneficiary);
    }

    function _forwardFunds()
        internal
        virtual
        override(Crowdsale, RefundableCrowdsale)
    {
        RefundableCrowdsale._forwardFunds();
    }

    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
        virtual
        override(Crowdsale, PostDeliveryCrowdsale)
    {
        PostDeliveryCrowdsale._processPurchase(beneficiary, tokenAmount);
    }
}

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conforms
 * the base architecture for crowdsales. It is not intended to be modified / overridden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropriate to concatenate
 * behavior.
 */

contract LaunchPadDeployer {
    uint256 public totalLaunchPads;
    LaunchPadInfo[] public launchPads;

    struct LaunchPadInfo {
        uint256 id;
        uint256 rate;
        address launchPadAddress;
        address payable wallet;
        IERC20 token;
        address payable tokenOwner;
        uint256 cap;
        uint256 openingTime;
        uint256 closingTime;
        uint256 goal;
        uint256 releaseTime;
    }

    function DeployLaunchPad(
        uint256 _rate,
        address payable _wallet,
        IERC20 _token,
        address payable tokenOwner,
        uint256 _cap,
        uint256 _openingTime,
        uint256 _closingTime,
        uint256 _goal,
        uint256 _releaseTime
    ) public returns (address) {
        CrowpadSale launchpad = new CrowpadSale(
            _rate,
            _wallet,
            _token,
            tokenOwner,
            _cap,
            _openingTime,
            _closingTime,
            _goal,
            _releaseTime
        );
        totalLaunchPads++;
        LaunchPadInfo memory data = LaunchPadInfo({
            id: totalLaunchPads,
            rate: _rate,
            wallet: _wallet,
            launchPadAddress: address(launchpad),
            token: _token,
            tokenOwner: tokenOwner,
            cap: _cap,
            openingTime: _openingTime,
            closingTime: _closingTime,
            goal: _goal,
            releaseTime: _releaseTime
        });
        launchPads.push(data);
        return (address(launchpad));
    }
}

contract CrowpadSale is
    Crowdsale,
    CappedCrowdsale,
    TimedCrowdsale,
    RefundablePostDeliveryCrowdsale,
    Ownable
{
    using SafeMath for uint256;

    // Track investor contributions
    uint256 public investorMinCap = 2000000000000000; // 0.002 ether
    uint256 public investorHardCap = 50000000000000000000; // 50 ether
    mapping(address => uint256) public contributions;

    // Crowdsale Stages
    enum CrowdsaleStage {
        PreICO,
        ICO
    }
    // Default to presale stage
    CrowdsaleStage public stage = CrowdsaleStage.PreICO;

    // Token Distribution
    uint256 public tokenSalePercentage = 70;

    // Token time lock
    uint256 public releaseTime;

    // Token Owner
    address payable private _tokenOwner;

    constructor(
        uint256 _rate,
        address payable _wallet,
        IERC20 _token,
        address payable tokenOwner,
        uint256 _cap,
        uint256 _openingTime,
        uint256 _closingTime,
        uint256 _goal,
        uint256 _releaseTime
    )
        Crowdsale(_rate, _wallet, _token)
        CappedCrowdsale(_cap)
        TimedCrowdsale(_openingTime, _closingTime)
        RefundablePostDeliveryCrowdsale(_goal)
    {
        require(_goal <= _cap, "Goal can not be greater than Cap.");
        releaseTime = _releaseTime;
        _tokenOwner = tokenOwner;
    }

    /**
     * @dev Returns the amount contributed so far by a sepecific user.
     * @param _beneficiary Address of contributor
     * @return User contribution so far
     */
    function getUserContribution(address _beneficiary)
        public
        view
        returns (uint256)
    {
        return contributions[_beneficiary];
    }

    /**
     * @dev Allows admin to update the crowdsale stage
     * @param _stage Crowdsale stage
     */
    function setCrowdsaleStage(uint256 _stage) public onlyOwner {
        if (uint256(CrowdsaleStage.PreICO) == _stage) {
            stage = CrowdsaleStage.PreICO;
        } else if (uint256(CrowdsaleStage.ICO) == _stage) {
            stage = CrowdsaleStage.ICO;
        }

        if (stage == CrowdsaleStage.PreICO) {
            // rate = 500;
            // change crowsale's rate
        } else if (stage == CrowdsaleStage.ICO) {
            // rate = 250;
            // change crowsale's rate
        }
    }

    /**
     * @dev Initial Deposite from tokenOwner
     * @param amount Total amount of deposite
     */
    function Deposite(uint256 amount) public {
        require(msg.sender == _tokenOwner, "Only token owner can deposite");
        require(token().balanceOf(_tokenOwner) > amount, "Insufficent balance");

        token().transfer(address(this), amount);
    }

    /**
     * @dev forwards funds to the wallet during the PreICO stage, then the refund vault during ICO stage
     */
    function _forwardFunds()
        internal
        override(Crowdsale, RefundablePostDeliveryCrowdsale)
    {
        if (stage == CrowdsaleStage.PreICO) {
            wallet().transfer(msg.value);
        } else if (stage == CrowdsaleStage.ICO) {
            super._forwardFunds();
        }
    }

    /**
     * @dev Extend parent behavior requiring purchase to respect investor min/max funding cap.
     * @param _beneficiary Token purchaser
     * @param _weiAmount Amount of wei contributed
     */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount)
        internal
        override(CappedCrowdsale, Crowdsale, TimedCrowdsale)
    {
        super._preValidatePurchase(_beneficiary, _weiAmount);
        uint256 _existingContribution = contributions[_beneficiary];
        uint256 _newContribution = _existingContribution.add(_weiAmount);
        require(
            _newContribution >= investorMinCap &&
                _newContribution <= investorHardCap,
            "investorMinCap < contribution < investorHardCap"
        );
        contributions[_beneficiary] = _newContribution;
    }

    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
        override(Crowdsale, RefundablePostDeliveryCrowdsale)
    {
        RefundablePostDeliveryCrowdsale._processPurchase(
            beneficiary,
            tokenAmount
        );
    }

    /**
     * @dev Escrow finalization task, called when finalize() is called.
     */
    function _finalization() internal virtual override {
        // Refund remained token to owner
        if (goalReached() && !capReached()) {
            _deliverTokens(_tokenOwner, token().balanceOf(address(this)));
        }

        super._finalization();
    }
}