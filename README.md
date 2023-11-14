# jpyc-purchase-v1

## JPYC Contract Address
- JPYC (Mainnet)：0x2370f9d504c7a6e775bf6e14b3f12846b594cd53
- JPYC (Ropsten)：https://ropsten.etherscan.io/token/0xdde5c1d6766cc56ed4be9922ad2c512dde4eafae
- JPYC (Rinkeby)：https://rinkeby.etherscan.io/token/0x995c66f0fa6666c2c3b2fc49f4442d588ebeda68

## Chainlink pricefeed contract address

### JPY - USD
- Mainnet：0xBcE206caE7f0ec07b545EddE332A47C2F75bbeb3
- Ropsten：0x795122664E4D4A3F7e66E8674953C97ADc60B17C
- Rinkeby：0x3Ae2F46a2D84e3D5590ee6Ee5116B80caF77DeCA

### ETH - USD
- Mainnet：0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
- Ropsten：0x6B927dc8cF91c69d9dBFbf630D8951709cB0885D
- Rinkeby：0x8A753747A1Fa494EC906cE90E9f37563A8AF630e

Detail：https://docs.chain.link/docs/ethereum-addresses/

## ERC20
### USDC (Rinkeby)
- Contract Address : 0x4dbcdf9b62e891a7cec5a2568c3f4faf9e8abe2b
- USDC-USD : 0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB

### DAI (Rinkeby)
- Contract Address : 0xc7ad46e0b8a400bb3c915120d284aafba8fc4735
- DAI-USD : 0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF


# Technical

## Overview
This is a smart contract that allow you to buy JPYC with crypto assets such as ETH and ERC20.

This is the summary of this smart contract.
- JPYC seller (JPYC.inc) approves their JPYC for this smart contract and send their JPYC.
  - This means the JPYC seller does not have to deposit JPYC, so we can limit the damage if the smart contract is exploited.
- Crypto assets paid for purchase JPYC are sent to the address of JPYC seller via smart contract in one transaction.
  - Crypto assets also will not send to smart contract.
- You can set tha minimum and maximum purchase amount.
- This smart contract supports multiple crypto assets in a single contract.
  - Supported currencies: USDC, DAI
  - Planning: WETH, UNI, WBTC, AAVE, SUSHI, COMP, MKR, YFI, REN, LRC, DPI
- Will be deployed on Ethereum, Polygon and xDai.
- There is authority to add supported currencies.


## Authority of `jpyc_supplier` (JPYC seller)

`jpyc_supplier` is registered as the so-colled "owner" of the smart contract, and `jpyc_supplier` has the following roles and authorities.

- Approving the contract for their JPYC in order to enable users to purchase JPYC.
- Authority to set maximum and minimum purchase amount.
- Authority to add the supported currency.
- Authority to modify `jpyc_supplyer`.

## How the rate is calculated

The rate for each currencies is fetched from Chainlink's price feed contract. We use `latestAnswer()`.

- JPY-USD: USD per JPY ex) 909389 (decimals 8)
- ETH-USD: USD per ETH ex)222265447281 (decimals 8)
- ERC20-USD: USD per 1ERC20

See Chainlink documentation for more detail about rate pairs.
- PriceFeed: https://docs.chain.link/docs/ethereum-addresses/

* Please note that the formula is USD/JPY, even though Channlink states JPY/USD.

### Rates for JPYC - ETH

Since Chainlink does not have the JPY-ETH rate, we use JPY-USD-ETH to get JPY-ETH rate.

#### JPYC → ETH

This function returns the amount of ETH corresponding to the amount of JPYC.

```
Formula: JPYYC * (JPY-USD) / (ETH-USD) = ETH
```

```sol
function getETHAmountFromJpyc (uint256 _jpycAmount) public view returns (uint256 ethAmount) {
  uint256 usdAmount = uint256(getLatestJpyUsdPrice()).mul(_jpycAmount);
  return ethAmount = usdAmount.div(uint256(getLatestEthUsdPrice()));
}
```

#### ETH → JPYC
This function returns the amount of JPYC corresponding to the amount of ETH.

```
Formula: ETH * (ETH-USD) / (JPY-USD) = JPYC
```

```sol
function getJpycAmountFromETH (uint256 _ethAmount) public view returns (uint256 jpycAmount) {
  uint256 usdAmount = uint256(getLatestEthUsdPrice()).mul(_ethAmount);
  return jpycAmount = usdAmount.div(uint256(getLatestJpyUsdPrice()));
}
```

### Rate for JPYC - ERC20
Since Chainlink supports a large number of ERC20-USD rates, we use JPY-USD-ERC20 for the calculation of JPYC-ERC20.

In order to support many ERC20s, we have mapped the ERC20 address with Chainlink price feed address.

```sol
mapping(address => AggregatorV3Interface) private priceFeedERC20Usd;

function addPriceFeed(address _tokenAddress, address _chainlinkPriceFeed) external onlyOwner {
    priceFeedERC20Usd[_tokenAddress] = AggregatorV3Interface(_chainlinkPriceFeed);
}
```

#### JPYC → ERC20
This function returns the amount of ERC20 corresponding to the amount of JPYC.

```
Formula：JPY * ( JPY-USD ) * ( ERC20 decimals ) / (ERC20-USD)
```

```sol
function getERC20AmountFromJpyc (uint256 _jpycAmount, address _tokenAddress) public view returns (uint256 erc20Amount) {
  uint256 usdAmount = uint256(getLatestJpyUsdPrice()).mul(_jpycAmount);
  return erc20Amount = usdAmount.div(10 ** (18 - IERC20(_tokenAddress).decimals())).div(uint256(getLatestERC20UsdPrice(_tokenAddress)));
}
```

### ERC20 → JPYC
This function returns the amount of JPYC corresponding to the amount of ERC20.

```
Formula：ERC20 * (ERC20-USD) / (JPY-USD) = JPYC
```

```sol
function getJpycAmountFromERC20 (uint _erc20Amount, address _tokenAddress) public view returns (uint256 jpycAmount) {
  uint256 usdAmount = uint256(getLatestERC20UsdPrice(_tokenAddress)).mul(_erc20Amount).mul(10 ** (18 - IERC20(_tokenAddress).decimals()));
  return jpycAmount = usdAmount.div(uint256(getLatestJpyUsdPrice()));
}
```

## Purchase function

The purchase functions are inspired by UniswapV2, and there are two patterns for purchases. We have created separate functions for ETH and ERC20, resulting in a total of four functions.

- One pattern is where the amount of JPYC you wish to purchase is fixed, and you pay the required crypto assets for that amount.
- The other pattern is where the amount of crypto asset you pay is fixed, and you receive an amount of JPYC calculated based on that payment.

Also, it may take time for transaction to be confirmed, for example, by setting a lower gas price, and the Chainlink rate may change in the meantime.

Therefore, we developed `SLIPPAGE`.

There are three requirements for purchase functions.
- Within the purchase limit: `require(minimumPurchaseAmount <= xx <= maximumPurchaseAmount);`
- Whether a sufficient amount of jpyc is approve for the contract from JPYC seller: `require(xx <= jpycInterface.allowance(jpyc_supplyer, address(this)));`
- Whether amount is within the slippage: `require(xx <= amountMax);`

### purchaseExactJpycWithETH

This function sets the value of the JPYC you wish to purchase and pays the ETH required to purchase that amount.
Unnecessary ETH will be refunded.

```sol
function purchaseExactJpycWithETH(uint256 _jpycAmount, uint256 _amountOutMax) payable external {
  require(minimumPurchaseAmount <= _jpycAmount && _jpycAmount <= maximumPurchaseAmount, "purchase amount must be within purchase range");
  require(_jpycAmount <= jpycInterface.allowance(jpyc_supplyer, address(this)), "insufficient allowance of JPYC");

  uint256 ethAmount = getETHAmountFromJpyc(_jpycAmount);
  require(ethAmount <= _amountOutMax, 'EXCESSIVE_SLIPPAGE_AMOUNT');
  require(msg.value >= ethAmount, "msg.value must greater than calculated ether amount");

  jpyc_supplyer.transfer(ethAmount);
  jpycInterface.transferFrom(jpyc_supplyer, msg.sender, _jpycAmount);

  if (msg.value > ethAmount) msg.sender.transfer(msg.value - ethAmount);
}
```

### purchaseJpycWithExactETH

This function sets the value of the ETH you wish to pay and receives JPYC corresponding to that amount.

```sol
function purchaseJpycWithExactETH(uint256 _amountInMin) payable external {
  uint256 jpycAmountFromEth = getJpycAmountFromETH(msg.value);
  require(minimumPurchaseAmount <= jpycAmountFromEth && jpycAmountFromEth <= maximumPurchaseAmount, "purchase amount must be within purchase range");
  require(jpycAmountFromEth <= jpycInterface.allowance(jpyc_supplyer, address(this)), "insufficient allowance of JPYC");
  require(jpycAmountFromEth >= _amountInMin, 'EXCESSIVE_SLIPPAGE_AMOUNT');

  jpyc_supplyer.transfer(msg.value);
  jpycInterface.transferFrom(jpyc_supplyer, msg.sender, jpycAmountFromEth);
}
```

### purchaseExactJpycWithERC20
This function sets the value of the JPYC you wish to purchase and pays the ERC20 required to purchase that amount.


```sol
function purchaseExactJpycWithERC20(uint256 _jpycAmount, uint256 _amountOutMax, address _tokenAddress) external {
  require(minimumPurchaseAmount <= _jpycAmount && _jpycAmount <= maximumPurchaseAmount, "purchase amount must be within purchase range");
  require(_jpycAmount <= jpycInterface.allowance(jpyc_supplyer, address(this)), "insufficient allowance of JPYC");

  uint256 erc20Amount = getERC20AmountFromJpyc(_jpycAmount, _tokenAddress);
  require(erc20Amount <= _amountOutMax, 'EXCESSIVE_SLIPPAGE_AMOUNT');
  require(IERC20(_tokenAddress).balanceOf(msg.sender) >= erc20Amount, "insufficient balance of ERC20 token");


  IERC20(_tokenAddress).transferFrom(msg.sender, jpyc_supplyer, erc20Amount);
  jpycInterface.transferFrom(jpyc_supplyer, msg.sender, _jpycAmount);
}
```

### purchaseJpycWithExactERC20
This function sets the value of the ERC20 you wish to pay and receives JPYC corresponding to that amount.

```sol
function purchaseJpycWithExactERC20(uint256 _erc20Amount, uint256 _amountInMin, address _tokenAddress) external {
  uint256 jpycAmountFromERC20 = getJpycAmountFromERC20(_erc20Amount, _tokenAddress);
  require(minimumPurchaseAmount <= jpycAmountFromERC20 && jpycAmountFromERC20 <= maximumPurchaseAmount, "purchase amount must be within purchase range");
  require(jpycAmountFromERC20 <= jpycInterface.allowance(jpyc_supplyer, address(this)), "insufficient allowance of JPYC");
  require(jpycAmountFromERC20 >= _amountInMin, 'EXCESSIVE_SLIPPAGE_AMOUNT');

  require(IERC20(_tokenAddress).balanceOf(msg.sender) >= _erc20Amount, "insufficient balance of ERC20 token");

  IERC20(_tokenAddress).transferFrom(msg.sender, jpyc_supplyer, _erc20Amount);
  jpycInterface.transferFrom(jpyc_supplyer, msg.sender, jpycAmountFromERC20);
}
```

## Things to check with each functions


As mentioned above, it may take some time for tx to be confirmed due to setting a lower gas rate, etc., and the chainlink rate may be changed during that time. Therefore, it is necessary to check whether tx is confirmed or reverted even if the chainlink rate is changed after tx is sent by each function.
In other words, it is necessary to consider the case where the chainlink rate does not change after the tx is sent (normal case) and the case where the chainlink rate changes after the tx is sent.

### purchaseExactJpycWithETH
- Error if purchase amount is outside purchase limit
- Error if more than the purchase amount of JPYC is not approved to the contract.
- Error if the amount of ETH to be paid is greater than the slippage
- Error if msg.value is less than the ETH converted from the purchase amount in JPYC
- Error if the msg.value is less than the ETH converted from the purchase amount in JPYC.
- If msg.value is more that the required amount, ETH will be refunded to sender.

### purchaseJpycWithExactETH
- Error if the JPYC to be received is less than the slippage (only when the rate changes)
- Error if the purchase amount is outside the purchase limit.
- Error if more than the purchase amount of JPYC is not approved to the contract.
- Error if msg.value is less than the amount of ETH converted from the purchase amount of JPYC.
- Other than the above, it will be confirmed.

### purchaseExactJpycWithERC20

- Error if the purchase amount is outside the purchase limit.
- Error if the purchase amount or more JPYC is not approved for the contract.
- Error if the ERC20 to be paid is greater than the slippage
- Error if the sender's ERC20 balance is less than the ERC20 converted from the purchase amount in JPYC.
- If the above is not the case, tx is confirmed.

### purchaseJpycWithExactERC20
- Error if the sender's ERC20 balance is less than the ERC20 converted from the purchase amount in JPYC.
- Error if the JPYC received is less than the slippage
- Error if the purchase amount is outside the purchase limit
- Error if more than the purchase amount of JPYC is not approved to the contract.
- tx is confirmed except for the above cases.
