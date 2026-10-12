// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
import "./SettlementBase.sol";

abstract contract PancakeSettlement is SettlementBase {
    address public constant WRAPPED =
        address(bytes20(hex"bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"));
    address public constant V2_FACTORY =
        address(bytes20(hex"ca143ce32fe78f1f7019d7d551a6402fc5350c73"));
    address public constant V2_ROUTER =
        address(bytes20(hex"10ed43c718714eb63d5aa57b78b54704e256024e"));
    address public constant V3_FACTORY =
        address(bytes20(hex"0bfbcf9fa4f9c56b0f40a671ad40e0805a091865"));
    address public constant V3_ROUTER =
        address(bytes20(hex"13f4ea83d0bd40e75c8222255bc855a974568dd4"));
    function _pair(address token, address pool) internal view returns (bool) {
        if (pool == address(0)) return false;
        return
            IV2Pair(pool).factory() == V2_FACTORY &&
            IV2Factory(V2_FACTORY).getPair(token, WRAPPED) == pool &&
            ((IV2Pair(pool).token0() == token &&
                IV2Pair(pool).token1() == WRAPPED) ||
                (IV2Pair(pool).token1() == token &&
                    IV2Pair(pool).token0() == WRAPPED));
    }
    function _v3(
        address token,
        address pool
    ) internal view returns (uint24 tier) {
        tier = IV3Pool(pool).fee();
        if (
            IV3Pool(pool).factory() != V3_FACTORY ||
            IV3Factory(V3_FACTORY).getPool(token, WRAPPED, tier) != pool
        ) revert UnsupportedMarket();
    }
    function _dexBuy(
        address token,
        uint8 venue,
        uint24 tier,
        uint256 amount,
        address recipient,
        uint256 deadline
    ) internal {
        if (venue == 1) {
            address[] memory p = new address[](2);
            p[0] = WRAPPED;
            p[1] = token;
            IV2Router(V2_ROUTER)
                .swapExactETHForTokensSupportingFeeOnTransferTokens{
                value: amount
            }(0, p, recipient, deadline);
        } else if (venue == 2) {
            uint256 beforeWrapped = IERC20(WRAPPED).balanceOf(address(this));
            IWrapped(WRAPPED).deposit{value: amount}();
            _approve(WRAPPED, V3_ROUTER, amount);
            IV3Router(V3_ROUTER).exactInputSingle(
                IV3Router.ExactInputSingleParams(
                    WRAPPED,
                    token,
                    tier,
                    recipient,
                    amount,
                    0,
                    0
                )
            );
            _approve(WRAPPED, V3_ROUTER, 0);
            uint256 unspent = IERC20(WRAPPED).balanceOf(address(this)) -
                beforeWrapped;
            if (unspent > 0) IWrapped(WRAPPED).withdraw(unspent);
        } else revert UnsupportedMarket();
    }
    function _dexSell(
        address token,
        uint8 venue,
        uint24 tier,
        uint256 amount,
        uint256 deadline
    ) internal {
        if (venue == 1) {
            address[] memory p = new address[](2);
            p[0] = token;
            p[1] = WRAPPED;
            _approve(token, V2_ROUTER, amount);
            IV2Router(V2_ROUTER)
                .swapExactTokensForETHSupportingFeeOnTransferTokens(
                    amount,
                    0,
                    p,
                    address(this),
                    deadline
                );
            _approve(token, V2_ROUTER, 0);
        } else if (venue == 2) {
            uint256 beforeBalance = IERC20(WRAPPED).balanceOf(address(this));
            _approve(token, V3_ROUTER, amount);
            IV3Router(V3_ROUTER).exactInputSingle(
                IV3Router.ExactInputSingleParams(
                    token,
                    WRAPPED,
                    tier,
                    address(this),
                    amount,
                    0,
                    0
                )
            );
            _approve(token, V3_ROUTER, 0);
            IWrapped(WRAPPED).withdraw(
                IERC20(WRAPPED).balanceOf(address(this)) - beforeBalance
            );
        } else revert UnsupportedMarket();
    }
}

interface IFlap {
    struct TokenState {
        uint8 status;
        uint256 reserve;
        uint256 circulatingSupply;
        uint256 price;
        uint8 tokenVersion;
        uint256 r;
        uint256 h;
        uint256 k;
        uint256 dexSupplyThresh;
        address quoteTokenAddress;
        bool nativeToQuoteSwapEnabled;
        bytes32 extensionID;
        uint256 buyTaxRate;
        uint256 sellTaxRate;
        address pool;
        uint256 progress;
        uint8 lpFeeProfile;
        uint8 dexId;
    }
    struct Swap {
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 minOutputAmount;
        bytes permitData;
    }
    function getTokenV8Safe(address) external view returns (TokenState memory);
    function swapExactInput(Swap calldata) external payable returns (uint256);
}
contract TradeSettlement is PancakeSettlement {
    address public constant PORTAL =
        address(bytes20(hex"e2ce6ab80874fa9fa2aae65d277dd6b8e65c9de0"));
    function stage(
        address token
    ) public view override returns (uint8, address, uint24) {
        IFlap.TokenState memory s = IFlap(PORTAL).getTokenV8Safe(token);
        if (
            s.tokenVersion > 7 ||
            (s.quoteTokenAddress != address(0) &&
                s.quoteTokenAddress != WRAPPED)
        ) revert UnsupportedMarket();
        if (s.status == 1) return (0, PORTAL, 0);
        if (s.status != 4 || s.dexId != 0) revert UnsupportedMarket();
        // V2 pair and V3 pool addresses are supported; Infinity vault / V4 manager are rejected.
        address pair = IV2Factory(V2_FACTORY).getPair(token, WRAPPED);
        if (s.pool == pair && _pair(token, pair)) return (1, pair, 0);
        return (2, s.pool, _v3(token, s.pool));
    }
    function _buy(
        address token,
        uint8 venue,
        address,
        uint24 tier,
        uint256 amount,
        address recipient,
        uint256 deadline
    ) internal override {
        if (venue == 0) {
            uint256 beforeBalance = IERC20(token).balanceOf(address(this));
            IFlap(PORTAL).swapExactInput{value: amount}(
                IFlap.Swap(address(0), token, amount, 0, "")
            );
            uint256 output = IERC20(token).balanceOf(address(this)) -
                beforeBalance;
            _token(token, abi.encodeCall(IERC20.transfer, (recipient, output)));
            if (IERC20(token).balanceOf(address(this)) != beforeBalance)
                revert AmountMismatch();
        } else _dexBuy(token, venue, tier, amount, recipient, deadline);
    }
    function _sell(
        address token,
        uint8 venue,
        address,
        uint24 tier,
        uint256 amount,
        uint256 deadline
    ) internal override {
        if (venue == 0) {
            _approve(token, PORTAL, amount);
            IFlap(PORTAL).swapExactInput(
                IFlap.Swap(token, address(0), amount, 0, "")
            );
            _approve(token, PORTAL, 0);
        } else _dexSell(token, venue, tier, amount, deadline);
    }
}
