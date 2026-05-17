/**
   * 消费时换汇
   * @param data
   * @param qbitCardObj
   * @returns
   */
  private async exchangeRateForConsumption(op: blueBanc.AuthorizationTransactionOperation) {
    const exchangeRateInfo: blueBanc.II2cFXResult = {
      /** 客户购物使用的原始币种 */
      originalCurrencyAmount: op.raw.cardAuth.txnAmount,
      /** 客户购物使用的原始金额 */
      originalCurrency: await switchCurrencyCode(op.raw.cardAuth.txnCurrencyCode),
      /** 三方清算金额 */
      thirdpartySettleAmount: op.raw.totalRequestAmount,
      /** 三方清算币种 */
      thirdpartySettleCurrency: 'USD',
      /** 汇率 */
      rate: 0,
      /** 转成USD的金额 */
      originalUSDAmount: 0,
      /** 我方使用的settleAmount，也是最终的USD的金额 */
      costAfterExchange: 0,
      markupRate: 0,
      markupFee: 0,
      rpRate: 0,
      rpFee: 0,
      qbitRate: 0,
      isSuccess: false,
      /** 真正的 markup-fee */
      markup_fee: 0,
      /** 跨境费 */
      cross_border_fee: 0,
      fx_markup_fee: 0,
      fx_markup_fee_rate: 0,
      rateSource: '',
      markup_fee_rate: 0,
      settleFee: 0,
      settleFeeRate: 0,
      markupCollectionRate: 0,
      markupCollectionFee: 0,
      markup_collection_fee: 0,
      fx_markup_collection_fee: 0,
      fx_markup_collection_fee_rate: 0,
      markup_collection_fee_rate: 0,
      settleCollectionFee: 0,
      settleCollectionFeeRate: 0,
      cross_border_collection_fee: 0,
      atmFee: 0,
      atmCollectionFee: 0,
      atmCollectionRate: 0,
      applePayFee: 0,
      crossBorderFeeBaseRate: 0,
      crossBorderFeeBaseCollectionRate: 0,
      fx_markup_pass_through_fee_rate: 0,
      fx_markup_pass_through_fee: 0,
    };
    op.exchangeRate = exchangeRateInfo;

    const unit = qbitIssuing.currencyUnit.find(item => item.currency === exchangeRateInfo.originalCurrency)?.unit ?? 2;
    exchangeRateInfo.originalCurrencyAmount = new Decimal(exchangeRateInfo.originalCurrencyAmount || 0).div(10 ** (unit - 2)).toNumber();

    try {
      // 取三方结算金额转美金的汇率
      if (exchangeRateInfo.thirdpartySettleCurrency == CurrencyEnum.USD) {
        exchangeRateInfo.rate = 1;
      } else {
        const { rate, rateSource } = await this.getRate(exchangeRateInfo.thirdpartySettleCurrency, CurrencyEnum.USD);
        exchangeRateInfo.rate = new Decimal(new Decimal(rate).toFixed(4, Decimal.ROUND_UP)).toNumber();
        exchangeRateInfo.rateSource = rateSource;
      }

      // 先获取结算美金的金额
      exchangeRateInfo.originalUSDAmount = new Decimal(
        new Decimal(exchangeRateInfo.thirdpartySettleAmount).mul(exchangeRateInfo.rate).toFixed(2, Decimal.ROUND_UP),
      ).toNumber();

      // 是否收费
      let isChargeFee = true;
      let isFxMarkupFee = true;

      const isUS = op.raw.cardAuth?.acceptorNameLoc?.slice(-2)?.toUpperCase() === 'US';

      if (exchangeRateInfo.originalCurrency === CurrencyEnum.USD) isFxMarkupFee = false;
      if (isUS) isChargeFee = false;

      if (isChargeFee) {
        const markup_fee_rate = await this.accountFeeV3Service.getAccountCardFee(
          op.qbitCard.accountId,
          AccountFeeTypeEnum.QuantumCardMarkUpFeePercentage,
          {
            provider: op.qbitCard.provider,
            firstSix: op.qbitCard.firstSix,
          },
        );
        exchangeRateInfo.markup_fee_rate = markup_fee_rate?.rate || 0;
        exchangeRateInfo.markup_fee = new Decimal(
          new Decimal(exchangeRateInfo.originalUSDAmount).mul(exchangeRateInfo.markup_fee_rate).toFixed(2, Decimal.ROUND_UP),
        ).toNumber();

        exchangeRateInfo.markup_collection_fee_rate = markup_fee_rate?.collectionRate || 0;
        exchangeRateInfo.markup_collection_fee = new Decimal(
          new Decimal(exchangeRateInfo.originalUSDAmount).mul(exchangeRateInfo.markup_collection_fee_rate).toFixed(2, Decimal.ROUND_UP),
        ).toNumber();

        const crossBorderFeeBaseRate = await this.accountFeeV3Service.getAccountCardFee(
          op.qbitCard.accountId,
          AccountFeeTypeEnum.QuantumCardCrossBorderFeeBaseRate,
          {
            provider: op.qbitCard.provider,
            firstSix: op.qbitCard.firstSix,
          },
        );
        exchangeRateInfo.crossBorderFeeBaseRate = crossBorderFeeBaseRate?.rate || 0;
        exchangeRateInfo.cross_border_fee = new Decimal(
          new Decimal(exchangeRateInfo.originalUSDAmount).mul(exchangeRateInfo.crossBorderFeeBaseRate).toFixed(2, Decimal.ROUND_UP),
        ).toNumber();

        exchangeRateInfo.crossBorderFeeBaseCollectionRate = crossBorderFeeBaseRate?.collectionRate || 0;
        exchangeRateInfo.cross_border_collection_fee = new Decimal(
          new Decimal(exchangeRateInfo.originalUSDAmount).mul(exchangeRateInfo.crossBorderFeeBaseCollectionRate).toFixed(2, Decimal.ROUND_UP),
        ).toNumber();
      }

      if (isFxMarkupFee) {
        const fx_markup_fee_rate = await this.accountFeeV3Service.getAccountCardFee(
          op.qbitCard.accountId,
          AccountFeeTypeEnum.QuantumCardFxMarkupFeeRate,
          {
            provider: op.qbitCard.provider,
            firstSix: op.qbitCard.firstSix,
          },
        );
        exchangeRateInfo.fx_markup_fee_rate = fx_markup_fee_rate?.rate || 0;
        exchangeRateInfo.fx_markup_fee = new Decimal(
          new Decimal(exchangeRateInfo.originalUSDAmount).mul(exchangeRateInfo.fx_markup_fee_rate).toFixed(2, Decimal.ROUND_UP),
        ).toNumber();

        exchangeRateInfo.fx_markup_collection_fee_rate = fx_markup_fee_rate?.collectionRate || 0;
        exchangeRateInfo.fx_markup_collection_fee = new Decimal(
          new Decimal(exchangeRateInfo.originalUSDAmount).mul(exchangeRateInfo.fx_markup_collection_fee_rate).toFixed(2, Decimal.ROUND_UP),
        ).toNumber();

        const fx_markup_fee_pass_through_rate = await this.accountFeeV3Service.getAccountCardFee(
          op.qbitCard.accountId,
          AccountFeeTypeEnum.QuantumCardFxMarkupPassThroughFeeRate,
          {
            provider: op.qbitCard.provider,
            firstSix: op.qbitCard.firstSix,
          },
        );
        exchangeRateInfo.fx_markup_pass_through_fee_rate = fx_markup_fee_pass_through_rate?.rate || 0;
        exchangeRateInfo.fx_markup_pass_through_fee = new Decimal(
          new Decimal(exchangeRateInfo.originalUSDAmount).mul(exchangeRateInfo.fx_markup_pass_through_fee_rate).toFixed(2, Decimal.ROUND_UP),
        ).toNumber();
      }

      exchangeRateInfo.markupFee = Math.max(
        new Decimal(exchangeRateInfo.markup_fee).add(exchangeRateInfo.cross_border_fee).toNumber(),
        new Decimal(exchangeRateInfo.fx_markup_fee).add(exchangeRateInfo.fx_markup_pass_through_fee).toNumber(),
      );

      exchangeRateInfo.markupRate = Math.max(
        new Decimal(exchangeRateInfo.markup_fee_rate).add(exchangeRateInfo.crossBorderFeeBaseRate).toNumber(),
        new Decimal(exchangeRateInfo.fx_markup_fee_rate).add(exchangeRateInfo.fx_markup_pass_through_fee_rate).toNumber(),
      );

      exchangeRateInfo.markupCollectionFee = Math.max(
        new Decimal(exchangeRateInfo.markup_collection_fee).add(exchangeRateInfo.cross_border_collection_fee).toNumber(),
        exchangeRateInfo.fx_markup_collection_fee,
      );
      exchangeRateInfo.markupCollectionRate = Math.max(
        new Decimal(exchangeRateInfo.markup_collection_fee_rate).toNumber(),
        exchangeRateInfo.fx_markup_collection_fee_rate,
      );

      exchangeRateInfo.costAfterExchange = new Decimal(exchangeRateInfo.originalUSDAmount).add(exchangeRateInfo.markupFee).toNumber();
      exchangeRateInfo.qbitRate = new Decimal(
        new Decimal(exchangeRateInfo.costAfterExchange).div(exchangeRateInfo.originalCurrencyAmount).toFixed(4, Decimal.ROUND_UP),
      ).toNumber();

      const settleFeeRate = await this.accountFeeV2Service.getQuantumCardSettleFee(
        op.qbitCard,
        exchangeRateInfo.costAfterExchange,
        isUS ? 'dom' : 'int',
        true,
      );
      exchangeRateInfo.settleFeeRate = settleFeeRate?.rate || 0;
      exchangeRateInfo.settleFee = new Decimal(
        new Decimal(exchangeRateInfo.costAfterExchange).mul(exchangeRateInfo.settleFeeRate).toFixed(2, Decimal.ROUND_UP),
      ).toNumber();

      exchangeRateInfo.settleCollectionFeeRate = settleFeeRate?.collectionRate || 0;
      exchangeRateInfo.settleCollectionFee = new Decimal(
        new Decimal(exchangeRateInfo.costAfterExchange).mul(exchangeRateInfo.settleCollectionFeeRate).toFixed(2, Decimal.ROUND_UP),
      ).toNumber();

      await this.atmAndApplePayFee(op);
      exchangeRateInfo.isSuccess = true;
    } catch (e) {
      op.qbitCardTx = await getManager().transaction(async manager => {
        return await this.createFailedQbitCardTxAndTransaction(manager, op, '无法获取到换汇汇率，请稍后重试');
      });
      throw { responseCode: 'DECLINE', reasonCode: blueBanc.ReasonCodeEnum.DO_NOT_HONOUR };
    }
  }