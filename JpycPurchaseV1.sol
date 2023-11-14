pragma solidity ^0.6.2;

interface IERC20 {
	function decimals() external view returns (uint256);
	function balanceOf(address account) external view returns (uint256);
	function allowance(address owner, address spender) external view returns (uint256);
	function transfer(address recipient, uint256 amount) external returns (bool);
	function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

library SafeMath {
	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		require(b <= a, "SafeMath: subtraction overflow");
		return a - b;
	}
	function mul(uint256 a, uint256 b) internal pure returns (uint256) {
		if (a == 0) {
			return 0;
		}
		uint256 c = a * b;
		require(c / a == b, "SafeMath: multiplication overflow");
		return c;
	}
	function div(uint256 a, uint256 b) internal pure returns (uint256) {
		return div(a, b, "SafeMath: division by zero");
	}
	function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
		require(b > 0, errorMessage);
		uint256 c = a / b;
		return c;
	}
}

interface AggregatorInterface {
	function latestAnswer() external view returns (int256);
}

contract JpycPurchase {

	using SafeMath for uint256;

	address payable jpyc_supplier;
	address public jpyc_address;
	uint256 internal jpyc_decimals;
	uint256 internal minimumPurchaseAmount;
	uint256 internal maximumPurchaseAmount;
	AggregatorInterface internal priceFeedNativeUsd;
	AggregatorInterface internal priceFeedJpyUsd;
	IERC20 internal jpycInterface;

	mapping(address => AggregatorInterface) private priceFeedERC20Usd;

	constructor(address _jpyc_address) public {
		jpyc_supplier = msg.sender;
		jpyc_address = _jpyc_address;
		jpycInterface = IERC20(_jpyc_address);
		jpyc_decimals = IERC20(_jpyc_address).decimals();
		minimumPurchaseAmount = 1000e18;
		maximumPurchaseAmount = 200000e18;
		priceFeedJpyUsd = AggregatorInterface(0x3Ae2F46a2D84e3D5590ee6Ee5116B80caF77DeCA);
		priceFeedNativeUsd = AggregatorInterface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
	}

	/**
	 * Returns the minimum purchase amount per transaction.
	 */
	function showMinimumPurchaseAmount() external view returns (uint256 _minimumPurchaseAmount)  {
		return minimumPurchaseAmount;
	}

	/**
	 * Returns the maximum purchase amount per transaction.
	 */
	function showMaximumPurchaseAmount() external view returns (uint256 _maximumPurchaseAmount)  {
		return maximumPurchaseAmount;
	}

	/**
	 * Returns the minimum purchase amount per transaction.
	 */
	function updateMinimumPurchaseAmount(uint _newMinimumPurchaseAmount) external onlyOwner {
		minimumPurchaseAmount = _newMinimumPurchaseAmount;
	}

	/**
	 * Changes the maximum purchase amount.
	 */
	function updateMaximumPurchaseAmount(uint _newMaximumPurchaseAmount) external onlyOwner {
		maximumPurchaseAmount = _newMaximumPurchaseAmount;
	}

	/**
	 * Returns the price feed contract interface of `_tokenAddress` and USD.
	 */
	function getPriceFeedContract(address _tokenAddress) external view returns (AggregatorInterface contractAddress) {
		return priceFeedERC20Usd[_tokenAddress];
	}

	/**
	 * Add the `_chainlinkPriceFeed` interface of `_tokenAddress` and USD.
	 */
	function addPriceFeed(address _tokenAddress, address _chainlinkPriceFeed) external onlyOwner {
		priceFeedERC20Usd[_tokenAddress] = AggregatorInterface(_chainlinkPriceFeed);
	}

	/**
	 * Change jpyc_supplier to `_jpycSupplier`.
	 */
	function changeJpycSupplier(address payable _jpycSupplier) public payable onlyOwner {
		require(_jpycSupplier != address(0), "_jpycSupplier is the zero address");
		jpyc_supplier = _jpycSupplier;
	}

	/**
	 * Returns the current Native token price in USD.
	 */
	function getLatestNativeUsdPrice() public view returns (int256) {
		return priceFeedNativeUsd.latestAnswer();
	}

	/**
	 * Returns the current JPY price in USD.
	 */
	function getLatestJpyUsdPrice() public view returns (int256) {
		return priceFeedJpyUsd.latestAnswer();
	}

	/**
	 * Returns the required `nativeAmount` for the `_jpycAmount` you input.
	 */
	function getNativeAmountFromJpyc (uint256 _jpycAmount) public view returns (uint256 nativeAmount) {
		uint256 usdAmount = uint256(getLatestJpyUsdPrice()).mul(_jpycAmount);
		return nativeAmount = usdAmount.div(uint256(getLatestNativeUsdPrice()));
	}

	/**
	 * Returns the `jpycAmount` equals to `_nativeAmount` you input.
	 */
	function getJpycAmountFromNative (uint256 _nativeAmount) public view returns (uint256 jpycAmount) {
		uint256 usdAmount = uint256(getLatestNativeUsdPrice()).mul(_nativeAmount);
		return jpycAmount = usdAmount.div(uint256(getLatestJpyUsdPrice()));
	}

	/**
	 * Receives exact amount of JPYC (_jpycAmount) for as much as Native token as possible, along the chainlink pricefeed.
	 */
	function purchaseExactJpycWithNative(uint256 _jpycAmount, uint256 _amountOutMax) payable external {
		require(minimumPurchaseAmount <= _jpycAmount && _jpycAmount <= maximumPurchaseAmount, "purchase amount must be within purchase range");
		require(_jpycAmount <= jpycInterface.allowance(jpyc_supplier, address(this)), "insufficient allowance of JPYC");

		uint256 nativeAmount = getNativeAmountFromJpyc(_jpycAmount);
		require(nativeAmount <= _amountOutMax, 'excessive slippage amount');
		require(msg.value >= nativeAmount, "msg.value must greater than calculated native token amount");

		jpyc_supplier.transfer(nativeAmount);
		jpycInterface.transferFrom(jpyc_supplier, msg.sender, _jpycAmount);

		if (msg.value > nativeAmount) msg.sender.transfer(msg.value - nativeAmount);
	}

	/**
	 * Receives as many JPYC  as possible for an msg.value of Native token, along the chinlink price feed.
	 */
	function purchaseJpycWithExactNative(uint256 _amountInMin) payable external {
    uint256 jpycAmountFromNative = getJpycAmountFromNative(msg.value);
		require(minimumPurchaseAmount <= jpycAmountFromNative && jpycAmountFromNative <= maximumPurchaseAmount, "purchase amount must be within purchase range");
		require(jpycAmountFromNative <= jpycInterface.allowance(jpyc_supplier, address(this)), "insufficient allowance of JPYC");
		require(jpycAmountFromNative >= _amountInMin, 'excessive slippage amount');

		jpyc_supplier.transfer(msg.value);
		jpycInterface.transferFrom(jpyc_supplier, msg.sender, jpycAmountFromNative);
  }


	/**
	 * Returns the current ERC20 of `_tokenAddress` price in USD.
	 */
	function getLatestERC20UsdPrice(address _tokenAddress) public view returns (int) {
		return priceFeedERC20Usd[_tokenAddress].latestAnswer();
	}

	/**
	 * Returns the required `erc20Amount` for the `_jpycAmount` you input.
	 */
	function getERC20AmountFromJpyc (uint256 _jpycAmount, address _tokenAddress) public view returns (uint256 erc20Amount) {
		uint256 usdAmount = uint256(getLatestJpyUsdPrice()).mul(_jpycAmount).div(10 ** (jpyc_decimals.sub(IERC20(_tokenAddress).decimals())));
		return erc20Amount = usdAmount.div(uint256(getLatestERC20UsdPrice(_tokenAddress)));
	}

	/**
	 * Returns the `jpycAmount` equals to `_erc20Amount` you input.
	 */
	function getJpycAmountFromERC20 (uint _erc20Amount, address _tokenAddress) public view returns (uint256 jpycAmount) {
		uint256 usdAmount = uint256(getLatestERC20UsdPrice(_tokenAddress)).mul(_erc20Amount).mul(10 ** (jpyc_decimals.sub(IERC20(_tokenAddress).decimals())));
		return jpycAmount = usdAmount.div(uint256(getLatestJpyUsdPrice()));
	}

	/**
	 * Receives exact amount of JPYC (_jpycAmount) for as much as ERC20 as possible, along the chainlink pricefeed.
	 */
	function purchaseExactJpycWithERC20(uint256 _jpycAmount, uint256 _amountOutMax, address _tokenAddress) external {
		require(minimumPurchaseAmount <= _jpycAmount && _jpycAmount <= maximumPurchaseAmount, "purchase amount must be within purchase range");
		require(_jpycAmount <= jpycInterface.allowance(jpyc_supplier, address(this)), "insufficient allowance of JPYC");

		uint256 erc20Amount = getERC20AmountFromJpyc(_jpycAmount, _tokenAddress);
		require(erc20Amount <= _amountOutMax, 'excessive slippage amount');
		require(IERC20(_tokenAddress).balanceOf(msg.sender) >= erc20Amount, "insufficient balance of ERC20 token");

		IERC20(_tokenAddress).transferFrom(msg.sender, jpyc_supplier, erc20Amount);
		jpycInterface.transferFrom(jpyc_supplier, msg.sender, _jpycAmount);
	}

	/**
	 * Receives as many JPYC  as possible for an _erc20Amount, along the chinlink price feed.
	 */
	function purchaseJpycWithExactERC20(uint256 _erc20Amount, uint256 _amountInMin, address _tokenAddress) external {
		uint256 jpycAmountFromERC20 = getJpycAmountFromERC20(_erc20Amount, _tokenAddress);
		require(minimumPurchaseAmount <= jpycAmountFromERC20 && jpycAmountFromERC20 <= maximumPurchaseAmount, "purchase amount must be within purchase range");
		require(jpycAmountFromERC20 <= jpycInterface.allowance(jpyc_supplier, address(this)), "insufficient allowance of JPYC");
		require(jpycAmountFromERC20 >= _amountInMin, 'excessive slippage amount');

		require(IERC20(_tokenAddress).balanceOf(msg.sender) >= _erc20Amount, "insufficient balance of ERC20 token");

		IERC20(_tokenAddress).transferFrom(msg.sender, jpyc_supplier, _erc20Amount);
		jpycInterface.transferFrom(jpyc_supplier, msg.sender, jpycAmountFromERC20);
	}

	function withdrawERC20(address _tokenAddress) onlyOwner external {
		IERC20(_tokenAddress).transfer(msg.sender, IERC20(_tokenAddress).balanceOf(address(this)));
	}

	modifier onlyOwner {
		require(
			msg.sender == jpyc_supplier,
			"msg.sender must be jpyc supplier."
		);
		_;
	}

}