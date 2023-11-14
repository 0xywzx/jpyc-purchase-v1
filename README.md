# jpyc-purchase-v1

## JPYC Contract Address
JPYC (Mainnet)：0x2370f9d504c7a6e775bf6e14b3f12846b594cd53
JPYC (Ropsten)：https://ropsten.etherscan.io/token/0xdde5c1d6766cc56ed4be9922ad2c512dde4eafae
JPYC (Rinkeby)：https://rinkeby.etherscan.io/token/0x995c66f0fa6666c2c3b2fc49f4442d588ebeda68

## Chanlink pricefeed contract address

### JPY - USD
Mainnet：0xBcE206caE7f0ec07b545EddE332A47C2F75bbeb3
Ropsten：0x795122664E4D4A3F7e66E8674953C97ADc60B17C
Rinkeby：0x3Ae2F46a2D84e3D5590ee6Ee5116B80caF77DeCA

### ETH - USD
Mainnet：0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
Ropsten：0x6B927dc8cF91c69d9dBFbf630D8951709cB0885D
Rinkeby：0x8A753747A1Fa494EC906cE90E9f37563A8AF630e

詳細：https://docs.chain.link/docs/ethereum-addresses/

## ERC20
### USDC (Rinkeby)
Contract Address : 0x4dbcdf9b62e891a7cec5a2568c3f4faf9e8abe2b
USDC-USD : 0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB

### DAI (Rinkeby)
Contract Address : 0xc7ad46e0b8a400bb3c915120d284aafba8fc4735
DAI-USD : 0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF


# 仕様書

## なんのコントラクトか
暗号資産（ETHやERC20）でJPYCを購入できるコントラクトです。主に下記の特徴を持っています。
-  JPYC販売者がコントラクトにapproveして、コントラクト経由でJPYCを送る
    - *JPYCはコントラクトにデポジットされません
- JPYCの購入で支払われた暗号資産は、JPYCをコントラクトにapproveした人に送られる
    - *コントラクト自体に暗号資産は送られません
    - 何かあった場合にapproveを取り消して購入できないようにするため,コントラクトにapproveする形にしています
- 購入上限額と下限額を設定
- オーナー権限の変更可
- 一つのコントラクトで複数の暗号資産に対応可
  - 対応予定通貨：USDC、DAI
  - 対応候補通貨：WETH、UNI、WBTC、AAVE、SUSHI、COMP、MKR、YFI、REN、LRC、DPI
- Ethereum, polygon, xDaiのチェーンでデプロイ予定

## jpyc_supplyerの権限
jpyc_supplyerをいわゆるコントラクトのownerとみなし、jpyc_supplyerに下記役割と権限を持たせています。
- コントラクトにJPYCをapproveして、コントラクトにJPYCを補充する役割
    - 厳密にはjpyc_supplyerのJPYCをコントラクトに対してapproveして、そのapproveされたものから購入者にJPYCが送金されます
- 購入上限額と下限額を設定する権限
- 対応する通貨を追加する権限
- jpyc_supplyerを変更する権限

## 販売レートの算出方法
各通貨のレートはChanlinkから取得しています。それぞれのレートはコントラクトの`latestAnswer()`から取得しています。
- JPY-USD：1円あたりのUSD　ex) 909389 (decimals 8)
- ETH-USD：1ETHあたりのUSD　ex)222265447281（decimals 8）
- ERC20-USD：1ERC20あたりのUSD

それぞれのレートのペアに関してはChanlinkを参照ください
PriceFeed：https://docs.chain.link/docs/ethereum-addresses/
* ChannlinkではJPY / USDと表現されてますが、計算式としてはUSD / JPYとなりますのでご注意ください

### JPYC - ETH のレート
ChainlinkにJPY-ETHのレートがないため、JPY - USD -  ETHで取得しています。

#### JPYC → ETH
JPYCの量に対応するETHの量を返す関数です。
計算式：JPYC * (JPY-USD) / (ETH-USD) = ETH
```sol
function getETHAmountFromJpyc (uint256 _jpycAmount) public view returns (uint256 ethAmount) {
  uint256 usdAmount = uint256(getLatestJpyUsdPrice()).mul(_jpycAmount);
  return ethAmount = usdAmount.div(uint256(getLatestEthUsdPrice()));
}
```

#### ETH → JPYC
ETHの量に対するJPYCの量を返す関数
計算式：ETH * (ETH-USD) / (JPY-USD) = JPYC
```sol
function getJpycAmountFromETH (uint256 _ethAmount) public view returns (uint256 jpycAmount) {
  uint256 usdAmount = uint256(getLatestEthUsdPrice()).mul(_ethAmount);
  return jpycAmount = usdAmount.div(uint256(getLatestJpyUsdPrice()));
}
```

### JPYC - ERC20のレートに関して
ChainlinkにはERC20 -USDのレートが多数用意されているため、JPYC - USD - ERC20 で算出しています。
複数のERC20に対応するために、ERC20のアドレスとChanlink price feed のアドレスを紐付けています。

```sol
mapping(address => AggregatorV3Interface) private priceFeedERC20Usd;

function addPriceFeed(address _tokenAddress, address _chainlinkPriceFeed) external onlyOwner {
    priceFeedERC20Usd[_tokenAddress] = AggregatorV3Interface(_chainlinkPriceFeed);
}
```

#### JPYC → ERC20
JPYCの量に対応するERC20の量を返す関数です。
計算式：JPY * ( JPY-USD ) * ( ERC20 decimals ) / (ERC20-USD)
```sol
function getERC20AmountFromJpyc (uint256 _jpycAmount, address _tokenAddress) public view returns (uint256 erc20Amount) {
  uint256 usdAmount = uint256(getLatestJpyUsdPrice()).mul(_jpycAmount);
  return erc20Amount = usdAmount.div(10 ** (18 - IERC20(_tokenAddress).decimals())).div(uint256(getLatestERC20UsdPrice(_tokenAddress)));
}
```

### ERC20 → JPYC
ERC20の量に対するJPYの量を返す関数です。
計算式：ERC20 * (ERC20-USD) / (JPY-USD) = JPYC

```sol
function getJpycAmountFromERC20 (uint _erc20Amount, address _tokenAddress) public view returns (uint256 jpycAmount) {
  uint256 usdAmount = uint256(getLatestERC20UsdPrice(_tokenAddress)).mul(_erc20Amount).mul(10 ** (18 - IERC20(_tokenAddress).decimals()));
  return jpycAmount = usdAmount.div(uint256(getLatestJpyUsdPrice()));
}
```

## 購入の関数に関して
販売に関してはUniswapを模倣して作成しており、購入方法は２パターンあります。（ETHとERC20が別になるので計4つの関数を用意しています）
- 欲しいJPYCの量を固定にして、その額に必要な暗号資産を算出し支払うパターン
- 支払う暗号資産の量を固定して支払い、その額に応じてJPYCを受け取るパターン

また、ガス代を低く設定するなどでtxがconfirmされるまでに時間がかかり、その間にchanlinkのレートが変更される可能性があります。そのため、slippageを設けております。

購入に関しては4点の必須条件(require)を設けています。
- 購入限度の範囲内か：`require(minimumPurchaseAmount <= xx <= maximumPurchaseAmount);`
- 十分な量のJPYCがコントラクトにapproveされてるか：`require( xx <= jpycInterface.allowance(jpyc_supplyer, address(this)));`
- slippageの範囲内か：`require(xx <= amountMax);`

### purchaseExactJpycWithETH
購入したいJPYCの値を決定して、その額に必要なETHを支払い購入する関数です。
不要なETHは返金するようにしています。
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
支払うETHの値を決定して、その額に対応するJPYCを受け取る関数です。
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
購入したいJPYCの値を決定して、その額に必要なERC20を支払い購入する関数です。

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
支払うERC20の値を決定して、その額に対応するJPYCを受け取る関数です。

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

## 各関数で確認すべき事項
前述したようにガス代を低く設定するなどでtxがconfirmされるまでに時間がかかり、その間にchanlinkのレートが変更される可能性があります。そのため、各関数でtx送信後にChanlinkのレートが変更になった場合でもtxがconfirmされるか、revertされるか確認する必要があります。
つまり、tx送信後にchanlinkのレートが変更しない（通常の場合）、tx送信後にchanlinkのレートが変更する場合を考慮する必要があります。

### purchaseExactJpycWithETH
- 購入額が購入限度額の範囲外の場合エラーになる
- 購入額以上のJPYCがコントラクトに approveされてない場合エラーになる
- 支払うETHがslippageより大きくなった場合エラーになる
- msg.valueが購入額のJPYCから換算されるETHより少ない場合はエラーになる
- 上記以外の場合、txはconfirmされる
- msg.valueが多い場合は送信元に返金される

### purchaseJpycWithExactETH
- 受け取れるJPYCがslippageより小さくなったらエラーになる（レート変更時のみ考慮）
- 購入額が購入限度額の範囲外の場合エラーになる
- 購入額以上のJPYCがコントラクトに approveされてない場合エラーになる
- msg.valueが購入額のJPYCから換算されるETHより少ない場合はエラーになる
- 上記以外はconfirmされる

### purchaseExactJpycWithERC20
- 購入額が購入限度額の範囲外の場合エラーになる
- 購入額以上のJPYCがコントラクトに approveされてない場合エラーになる
- 支払うERC20がslippageより大きくなった場合エラーになる
- 送信者のERC20の残高が購入額のJPYCから換算されるERC20より少ない場合はエラーになる
- 上記以外の場合、txはconfirmされる

### purchaseJpycWithExactERC20
- 送信者のERC20の残高が購入額のJPYCから換算されるERC20より少ない場合はエラーになる
- 受け取れるJPYCがslippageより小さく場合エラーになる
- 購入額が購入限度額の範囲外の場合エラーになる
- 購入額以上のJPYCがコントラクトに approveされてない場合エラーになる
- 上記以外の場合、txはconfirmされる
