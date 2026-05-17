/**
   * 消费时换汇
   * @param data
   * @param qbitCardObj
   * @returns
   */
  private async exchangeRateForConsumption(op: slash.AuthorizationTransactionOperation) {
    const exchangeRateInfo: slash.IVisaFXResult = {
      /** 客户购物使用的原始币种 */
      originalCurrencyAmount: this.dealAmount(op.raw.currencyConversion.originalAmountCents, op.raw.currencyConversion.originalCurrencyCode),
      /** 客户购物使用的原始金额 */
      originalCurrency: op.raw.currencyConversion.originalCurrencyCode,
      /** 三方清算金额 */
      thirdpartySettleAmount: this.dealAmount(op.raw.amount.amountCents, 'USD'),
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
      markup_fee_rate: 0,
      crossBorderFeeBaseRate: 0,
      /** 跨境费 */
      cross_border_fee: 0,
      fx_markup_fee: 0,
      fx_markup_fee_rate: 0,
      rateSource: '',
      atmFee: 0,
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
      crossBorderFeeBaseCollectionRate: 0,
      atmCollectionFee: 0,
      cross_border_collection_fee: 0,
      atmCollectionRate: 0,
      settleCollectionFeeRateV2: 0,
      settleFeeRateV2: 0,
      applePayFee: 0,
      fx_markup_pass_through_fee_rate: 0,
      fx_markup_pass_through_fee: 0,
    };
    op.exchangeRate = exchangeRateInfo;

    // 美金
    const isUS = ['US', 'USA'].includes(op.merchantData?.country?.toUpperCase());

    try {
      // 取三方结算金额转美金的汇率
      if (exchangeRateInfo.thirdpartySettleCurrency == CurrencyEnum.USD) {
        exchangeRateInfo.rate = 1;
      } else {
        // 还不知道有没有其他币种
        throw { approved: false, reason: 'Abnormal settlement currency' };
      }

      // 先获取结算美金的金额
      exchangeRateInfo.originalUSDAmount = new Decimal(
        new Decimal(exchangeRateInfo.thirdpartySettleAmount).mul(exchangeRateInfo.rate).toFixed(2, Decimal.ROUND_UP),
      ).toNumber();

      // 是否收费
      let isChargeFee = true;
      let isFxMarkupFee = true;
      if (isUS) isChargeFee = false;
      if (exchangeRateInfo.originalCurrency === CurrencyEnum.USD) isFxMarkupFee = false;

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

        const fee = new Decimal(exchangeRateInfo.fx_markup_fee).add(exchangeRateInfo.fx_markup_pass_through_fee).toNumber();
        if (fee > 0 && new Decimal(fee).lessThan(0.4)) {
          exchangeRateInfo.fx_markup_fee = Math.max(fee, 0.4);
          exchangeRateInfo.fx_markup_pass_through_fee = 0;
        }
      }

      exchangeRateInfo.markupFee = Math.max(
        new Decimal(exchangeRateInfo.markup_fee).add(exchangeRateInfo.cross_border_fee).toNumber(),
        new Decimal(exchangeRateInfo.fx_markup_fee).add(exchangeRateInfo.fx_markup_pass_through_fee).toNumber(),
      );

      exchangeRateInfo.markupCollectionFee = Math.max(
        new Decimal(exchangeRateInfo.markup_collection_fee).add(exchangeRateInfo.cross_border_collection_fee).toNumber(),
        exchangeRateInfo.fx_markup_collection_fee,
      );

      exchangeRateInfo.markupRate = Math.max(
        new Decimal(exchangeRateInfo.markup_fee_rate).add(exchangeRateInfo.crossBorderFeeBaseRate).toNumber(),
        new Decimal(exchangeRateInfo.fx_markup_fee_rate).add(exchangeRateInfo.fx_markup_pass_through_fee_rate).toNumber(),
      );

      exchangeRateInfo.markupCollectionRate = Math.max(
        new Decimal(exchangeRateInfo.markup_collection_fee_rate).add(exchangeRateInfo.crossBorderFeeBaseCollectionRate).toNumber(),
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
        false,
      );
      exchangeRateInfo.settleFeeRate = settleFeeRate?.rate || 0;
      exchangeRateInfo.settleFee = exchangeRateInfo.settleFeeRate;

      exchangeRateInfo.settleCollectionFeeRate = settleFeeRate?.collectionRate || 0;
      exchangeRateInfo.settleCollectionFee = exchangeRateInfo.settleCollectionFeeRate;

      const settleFeeRateV2 = await this.accountFeeV2Service.getQuantumCardSettleFee(
        op.qbitCard,
        exchangeRateInfo.costAfterExchange,
        isUS ? 'dom' : 'int',
        true,
      );

      exchangeRateInfo.settleFeeRateV2 = settleFeeRateV2?.rate || 0;
      const settleFeeV2 = new Decimal(
        new Decimal(exchangeRateInfo.costAfterExchange).mul(exchangeRateInfo.settleFeeRateV2).toFixed(2, Decimal.ROUND_UP),
      ).toNumber();
      exchangeRateInfo.settleCollectionFeeRateV2 = settleFeeRateV2?.collectionRate || 0;
      const settleCollectionFeeV2 = new Decimal(
        new Decimal(exchangeRateInfo.costAfterExchange).mul(exchangeRateInfo.settleCollectionFeeRateV2).toFixed(2, Decimal.ROUND_UP),
      ).toNumber();

      exchangeRateInfo.settleFee = new Decimal(exchangeRateInfo.settleFeeRate).add(settleFeeV2).toNumber();

      exchangeRateInfo.settleCollectionFee = new Decimal(exchangeRateInfo.settleCollectionFeeRate).add(settleCollectionFeeV2).toNumber();

      exchangeRateInfo.isSuccess = true;
    } catch (e) {
      op.qbitCardTx = await getManager().transaction(async manager => {
        return await this.createFailedQbitCardTxAndTransaction(manager, op, '无法获取到换汇汇率，请稍后重试');
      });
      throw { approved: false, reason: 'Abnormal exchange rate' };
    }
  }