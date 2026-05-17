/**
   * 消费时换汇
   * @param data
   * @param qbitCardObj
   * @returns
   */
  private async exchangeRateForConsumption(op: qbitIssuing.AuthorizationTransactionOperation) {
    const exchangeRateInfo: qbitIssuing.IVisaFXResult = {
      /** 客户购物使用的原始币种 */
      originalCurrencyAmount: this.dealAmount(op.raw.amountTransaction, op.raw.currencyCodeTransaction),
      /** 客户购物使用的原始金额 */
      originalCurrency: await switchCurrencyCode(op.raw.currencyCodeTransaction),
      /** 三方清算金额 */
      thirdpartySettleAmount: this.dealAmount(op.raw.amountCardholderBilling, op.raw.currencyCodeCardholderBilling),
      /** 三方清算币种 */
      thirdpartySettleCurrency: await switchCurrencyCode(op.raw.currencyCodeCardholderBilling),
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
      amountAccount: this.dealAmount(op.raw.amountAccount, op.raw.currencyCodeAccount),
      currencyCodeAccount: await switchCurrencyCode(op.raw.currencyCodeAccount),
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

    const isHk = op.raw.country === 'HK';

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

      // 判断是否交易币种也是美金
      if (exchangeRateInfo.rate !== 1 && exchangeRateInfo.originalCurrency === CurrencyEnum.USD) {
        // 按【交易金额/美金金额】 算一把汇率，如果是差额大于10%，按原来的逻辑走(怕交易金额搞错了，兜底一把)。
        const rate = new Decimal(exchangeRateInfo.originalCurrencyAmount).div(exchangeRateInfo.thirdpartySettleAmount).toFixed(4, Decimal.ROUND_UP);
        // 计算差额
        const subRate = new Decimal(rate)
          .sub(exchangeRateInfo.rate)
          .abs()
          .div(rate)
          .toFixed(4, Decimal.ROUND_UP);
        if (new Decimal(subRate).lessThan(new Decimal(0.1))) {
          exchangeRateInfo.originalUSDAmount = exchangeRateInfo.originalCurrencyAmount;
        }
      }

      // 是否收费
      let isChargeFee = true;
      let isFxMarkupFee = true;
      if ([QbitCardProviderEnum.QbitIssuingCard49387519, QbitCardProviderEnum.QbitIssuingCardRecharge49387519].includes(op.qbitCard.provider)) {
        // 49387519-USD 当订单币种为非USD或merchant所在地非HK时
        if (isHk) isChargeFee = false;
        if (exchangeRateInfo.originalCurrency === CurrencyEnum.USD) isFxMarkupFee = false;
      } else {
        // 49387520-HKD 当订单币种为非HKD或merchant所在地非HK时
        if (isHk) isChargeFee = false;
        if (exchangeRateInfo.originalCurrency === CurrencyEnum.HKD) isFxMarkupFee = false;
      }

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
        isHk ? 'dom' : 'int',
        false,
      );

      exchangeRateInfo.settleFeeRate = settleFeeRate?.rate || 0;
      exchangeRateInfo.settleFee = exchangeRateInfo.settleFeeRate;

      exchangeRateInfo.settleCollectionFeeRate = settleFeeRate?.collectionRate || 0;
      exchangeRateInfo.settleCollectionFee = exchangeRateInfo.settleCollectionFeeRate;

      // qi 还支持 百分比费
      const settleFeeRateV2 = await this.accountFeeV2Service.getQuantumCardSettleFee(
        op.qbitCard,
        exchangeRateInfo.costAfterExchange,
        isHk ? 'dom' : 'int',
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
      await this.atmAndApplePayFee(op);
    } catch (e) {
      op.qbitCardTx = await getManager().transaction(async manager => {
        return await this.createFailedQbitCardTxAndTransaction(manager, op, '无法获取到换汇汇率，请稍后重试');
      });
      throw { id: op.raw.id, code: qbitIssuing.CodeEnum.CBSRC_841 };
    }
  }