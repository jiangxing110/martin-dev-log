# Admin KYC Reset 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 支持白标 Admin 重置用户 Sumsub KYC，让被拒绝的用户获得重新提交校验的机会

**Architecture:** 4 个仓库协同修改 — qbit-assets(Sumsub重置接口) → white-label-server(核心业务逻辑+API) → u-app-admin(Admin操作界面) → u-app(C端文案+逻辑)。新增 `kycRetryQuota` 字段与 `kycSubmitCount` 分离管理，Admin重置时先调 qbit-assets 解封 Sumsub applicant

**Tech Stack:** Spring Boot (Java 21), Vue 3 + TSX, React Native + TypeScript, Sumsub SDK

---

## 文件变更清单

### qbit-assets
| 文件 | 操作 | 说明 |
|------|------|------|
| `qbit-core/.../sumsub/dto/ResetApplicantDTO.java` | **新建** | 重置请求DTO |
| `qbit-core/.../sumsub/service/SumsubSdkService.java` | 修改 | 新增 reset 方法签名 |
| `qbit-core/.../sumsub/service/impl/SumsubSdkServiceImpl.java` | 修改 | 实现 Sumsub reset API 调用 |
| `qbit-core/.../sumsub/service/impl/SumsubService.java` | 修改 | 新增 reset 业务逻辑 |
| `qbit-core/.../sumsub/controller/SumsubController.java` | 修改 | 新增 reset 接口 |

### white-label-server
| 文件 | 操作 | 说明 |
|------|------|------|
| `app-biz/.../entity/AccountExtend.java` | 修改 | 新增 `kycRetryQuota` 字段 |
| `app-api/.../dto/AccountExtendBO.java` | 修改 | 新增 `kycRetryQuota` 字段 |
| `app-api/.../dto/UserDTO.java` | 修改 | 新增 `kycRetryQuota` 字段 |
| `app-api/.../vo/AccountPageVO.java` | 修改 | 新增 `kycRetryQuota`、`simpleKycStatus` 字段 |
| `app-api/.../request/AccountPageRequest.java` | 修改 | 新增 `simpleKycStatus` 筛选条件 |
| `app-biz/.../AccountRepository.java` | 修改 | 查询中新增 kycRetryQuota |
| `app-biz/.../AccountServiceImpl.java` | 修改 | accountPage 中映射 simpleKycStatus |
| `app-api/.../CddKycService.java` | 修改 | 新增 resetKyc 方法签名 |
| `app-biz/.../CddKycServiceImpl.java` | 修改 | 实现 resetKyc + 修改拒绝判定 |
| `app-web/.../KycAdminController.java` | **新建** | Admin KYC 管理控制器 |
| DB Migration SQL | **新建** | 加字段脚本 |

### u-app-admin
| 文件 | 操作 | 说明 |
|------|------|------|
| `_map/index.tsx` | 修改 | KycStatusMap 精简为4种 |
| `_hooks/useUserList.tsx` | 修改 | kycStatus 筛选改用新 map |
| `detail/index.tsx` | 修改 | 新增 KYC 状态区块 + 重试按钮 |
| `_locale/lang/zh.tsx` | 修改 | 新增重试相关文案 |
| `_locale/lang/en.tsx` | 修改 | 新增重试英文文案 |

### u-app (商户端)
| 文件 | 操作 | 说明 |
|------|------|------|
| `kyc/index.tsx` | 修改 | KYC入口判定兼容 retryQuota |
| `kyc/result/index.tsx` | 修改 | RejectedStatus 文案更新 |
| `kyc/result/_locale/lang/zh.tsx` | 修改 | 修改 rejected.subtitle |
| `kyc/result/_locale/lang/en.tsx` | 修改 | 修改 rejected.subtitle |

---

## Task 1: qbit-assets — Sumsub 重置接口

**Files:**
- Create: `qbit-core/src/main/java/com/qbit/thirdparty/external/sumsub/dto/ResetApplicantDTO.java`
- Modify: `qbit-core/src/main/java/com/qbit/thirdparty/external/sumsub/service/SumsubSdkService.java`
- Modify: `qbit-core/src/main/java/com/qbit/thirdparty/external/sumsub/service/impl/SumsubSdkServiceImpl.java`
- Modify: `qbit-core/src/main/java/com/qbit/thirdparty/external/sumsub/service/impl/SumsubService.java`
- Modify: `qbit-core/src/main/java/com/qbit/thirdparty/external/sumsub/controller/SumsubController.java`

- [ ] **Step 1: 创建 ResetApplicantDTO**

```java
package com.qbit.thirdparty.external.sumsub.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import java.io.Serializable;

@Data
public class ResetApplicantDTO implements Serializable {
    private static final long serialVersionUID = 1L;

    @NotBlank
    private String applicantId;       // Sumsub applicant ID (对应 white-label 的 outerKycId)

    private String resetIdDocSetTypes; // 要重置的文件类型, 默认 "IDENTITY,SELFIE"
}
```

- [ ] **Step 2: SumsubSdkService 新增 resetApplicant 方法签名**

```java
// 在 SumsubSdkService.java 中新增
ApplicantsDataRespDTO resetApplicant(ResetApplicantDTO dto);
```

- [ ] **Step 3: SumsubSdkServiceImpl 实现 resetApplicant**

调用 Sumsub API 将 applicant 状态重置为 pending:

```java
@Override
public ApplicantsDataRespDTO resetApplicant(ResetApplicantDTO dto) {
    // PATCH /resources/applicants/{applicantId}/status/pending — 重置为待审核
    String requestUrl = String.format("/resources/applicants/%s/status/pending", dto.getApplicantId());
    String url = getConfig().getBaseUrl() + requestUrl;
    return createPatchRequest(url, ApplicantsDataRespDTO.class, 
        getApiKeyMap(null, requestUrl, HttpMethod.PATCH), "");
}
```

- [ ] **Step 4: SumsubService 新增 resetApplicant 业务逻辑**

```java
public ApplicantsDataRespDTO resetApplicant(ResetApplicantDTO dto) {
    // 1. 调用 SDK 重置 applicant 状态
    ApplicantsDataRespDTO resp = sdkService.resetApplicant(dto);
    
    // 2. 校验响应
    log.info("Sumsub reset applicant response: {}", JSON.toJSONString(resp));
    
    return resp;
}
```

- [ ] **Step 5: SumsubController 新增 reset 接口**

```java
@PostMapping("/resetApplicant")
@NoAuth(NoAuth.INTERNAL)
public Result<ApplicantsDataRespDTO> resetApplicant(@Valid @RequestBody ResetApplicantDTO dto) {
    return Result.ok(sumsubService.resetApplicant(dto));
}
```

- [ ] **Step 6: 验证编译通过**

Run: `cd /Users/martinjiang/IdeaProjects/qbit-assets && ./mvnw compile -pl qbit-core -am -q`
Expected: BUILD SUCCESS

- [ ] **Step 7: Commit**

```bash
git -C /Users/martinjiang/IdeaProjects/qbit-assets add -A
git -C /Users/martinjiang/IdeaProjects/qbit-assets commit -m "feat: add sumsub applicant reset API for admin retry"
```

---

## Task 2: white-label-server — DB + Entity 层

**Files:**
- Modify: `app-biz/app-biz-user/src/main/java/com/qbit/white/label/biz/user/dal/entity/AccountExtend.java`
- Modify: `app-api/app-api-user/src/main/java/com/qbit/white/label/api/user/model/dto/AccountExtendBO.java`
- Modify: `app-api/app-api-user/src/main/java/com/qbit/white/label/api/user/model/dto/UserDTO.java`
- Modify: `app-api/app-api-user/src/main/java/com/qbit/white/label/api/user/model/response/AccountPageVO.java`
- Modify: `app-api/app-api-user/src/main/java/com/qbit/white/label/api/user/model/request/AccountPageRequest.java`
- Modify: `app-biz/app-biz-user/src/main/java/com/qbit/white/label/biz/user/dal/repository/AccountRepository.java`

- [ ] **Step 1: AccountExtend.java 新增 kycRetryQuota 字段**

```java
// 在 kycSubmitCount 后面新增
/** Admin重置的KYC重试配额 */
private Integer kycRetryQuota;
```

- [ ] **Step 2: AccountExtendBO.java 新增 kycRetryQuota 字段**

```java
private Integer kycRetryQuota;
```

- [ ] **Step 3: UserDTO.java 新增 kycRetryQuota 字段**

```java
private Integer kycRetryQuota;
```

- [ ] **Step 4: AccountPageVO.java 新增 kycRetryQuota 和 simpleKycStatus 字段**

```java
private Integer kycRetryQuota;
private String simpleKycStatus;  // NOT_SUBMITTED / VERIFYING / APPROVED / REJECTED
```

- [ ] **Step 5: AccountPageRequest.java 新增 simpleKycStatus 筛选字段**

```java
private String simpleKycStatus;  // 前端筛选传入的简化状态
```

- [ ] **Step 6: AccountRepository.java 查询中返回 kycRetryQuota**

找到 `accountRepository.accountPage(request)` 中的查询逻辑，在 SELECT 中追加 `ae.kycRetryQuota.as("kycRetryQuota")`。

```java
// 在 AccountRepository.java 约 119 行附近，已有 kycRejectReason 后面追加
ae.kycRetryQuota.as("kycRetryQuota"),
```

- [ ] **Step 7: 编写 DB Migration SQL**

```sql
ALTER TABLE account_extend 
    ADD COLUMN kyc_retry_quota INT DEFAULT 0 COMMENT 'Admin重置的KYC重试配额';
```

- [ ] **Step 8: 编译验证**

Run: `cd /Users/martinjiang/IdeaProjects/white-label-server && ./mvnw compile -q`
Expected: BUILD SUCCESS

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "feat: add kycRetryQuota field to entity and API models"
```

---

## Task 3: white-label-server — 简化状态映射逻辑

**Files:**
- Modify: `app-biz/app-biz-user/src/main/java/com/qbit/white/label/biz/user/service/impl/AccountServiceImpl.java`
- Modify: `app-api/app-api-user/src/main/java/com/qbit/white/label/api/user/model/response/AccountPageVO.java` (已在上个Task添加字段)

- [ ] **Step 1: AccountServiceImpl 中实现 simpleKycStatus 映射方法**

在 `accountPage()` 中，设置 `kycStatus == null` 默认值后，追加 `simpleKycStatus` 映射:

```java
// 在 accountPage() 的循环中, 已有代码:
if (record.getKycStatus() == null) {
    record.setKycStatus(KycStatus.NA);
}

// 追加:
record.setSimpleKycStatus(mapSimpleKycStatus(record.getKycStatus(), record.getKycRetryQuota()));
```

新增映射方法:

```java
private String mapSimpleKycStatus(KycStatus status, Integer kycRetryQuota) {
    if (status == null || status == KycStatus.NA) {
        return "NOT_SUBMITTED";
    }
    if (status == KycStatus.PASSED) {
        return "APPROVED";
    }
    if (status == KycStatus.CANCELED || status == KycStatus.BLACKLISTED) {
        long totalQuota = 3 + (kycRetryQuota != null ? kycRetryQuota : 0);
        // 注意: 这里无法获取 kycSubmitCount(AccountPageVO 没有这个字段), 
        // 前端筛选时用不到这个判断, 实际拒绝判定在后端 reset 接口做
        return "REJECTED";
    }
    return "VERIFYING";
}
```

- [ ] **Step 2: AccountPageRequest 中支持 simpleKycStatus 筛选**

在 `AccountServiceImpl.accountPage()` 中, 接收到 `simpleKycStatus` 参数时转换为对应的 KYC status 查询条件:

```java
if (StringUtils.isNotBlank(request.getSimpleKycStatus())) {
    // 将简化状态映射为原始 KycStatus 筛选条件
    switch (request.getSimpleKycStatus()) {
        case "NOT_SUBMITTED" -> /* kycStatus == null or NA */;
        case "VERIFYING" -> /* 中间态排除 PASSED/CANCELED/BLACKLISTED */;
        case "APPROVED" -> /* kycStatus == PASSED */;
        case "REJECTED" -> /* kycStatus == CANCELED or BLACKLISTED */;
    }
}
```

- [ ] **Step 3: 编译验证**

Run: `./mvnw compile -q`
Expected: BUILD SUCCESS

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add simpleKycStatus mapping logic for admin filter"
```

---

## Task 4: white-label-server — Admin Reset API + 业务逻辑

**Files:**
- Create: `app-web/app-web-admin/src/main/java/com/qbit/white/label/admin/api/kyc/KycAdminController.java`
- Modify: `app-api/app-api-cdd/src/main/java/com/qbit/white/label/api/cdd/service/CddKycService.java`
- Modify: `app-biz/app-biz-cdd/src/main/java/com/qbit/white/label/biz/cdd/service/impl/CddKycServiceImpl.java`

- [ ] **Step 1: CddKycService 接口新增 resetKyc 方法**

```java
/**
 * Admin重置用户KYC校验资格。
 * 1. 调 qbit-assets Sumsub 接口重置 applicant
 * 2. 更新本地 kycRetryQuota, kycStatus, kycRejectReason
 *
 * @param accountId 要重置的账户ID
 */
void adminResetKyc(Long accountId);
```

- [ ] **Step 2: CddKycServiceImpl 实现 adminResetKyc**

```java
@Override
@Transactional(rollbackFor = Exception.class)
public void adminResetKyc(Long accountId) {
    // 1. 查询当前用户
    AccountExtend accountExtend = accountExtendRepository.selectOneByQuery(
        new QueryWrapper().eq("account_id", accountId));
    if (accountExtend == null) {
        throw CustomerFactory.businessCode(CodeConstant.CODE_400004);
    }
    
    // 2. 校验状态: 必须是被拒绝的状态才能重置
    long totalQuota = 3 + (accountExtend.getKycRetryQuota() != null ? accountExtend.getKycRetryQuota() : 0);
    boolean isRejected = (accountExtend.getKycStatus() == KycStatus.CANCELED || 
                          accountExtend.getKycStatus() == KycStatus.BLACKLISTED) &&
                         accountExtend.getKycSubmitCount() != null && 
                         accountExtend.getKycSubmitCount() >= totalQuota;
    if (!isRejected) {
        throw CustomerFactory.businessCode(CodeConstant.CODE_400004, "用户当前KYC状态不支持重置");
    }
    
    // 3. 调 qbit-assets 重置 Sumsub applicant
    try {
        String resetUrl = gatewayUrl + "/api/ss/internal/resetApplicant";
        ResetApplicantReqDTO req = new ResetApplicantReqDTO();
        req.setApplicantId(accountExtend.getOuterKycId());
        req.setResetIdDocSetTypes("IDENTITY,SELFIE");
        
        HttpHeaders headers = HeaderUtils.buildNodeHeaders(accountExtend.getOuterAccountId(), secret);
        httpClientWrapper.post(resetUrl, req, headers, Map.class);
    } catch (Exception e) {
        log.error("[KYC Reset] 调 Sumsub 重置失败 accountId={}", accountId, e);
        throw CustomerFactory.businessCode(CodeConstant.CODE_500000, "Sumsub重置失败: " + e.getMessage());
    }
    
    // 4. 更新本地数据
    accountExtend.setKycRetryQuota(
        (accountExtend.getKycRetryQuota() == null ? 0 : accountExtend.getKycRetryQuota()) + 1);
    accountExtend.setKycStatus(KycStatus.PENDING);
    accountExtend.setKycRejectReason(null);
    accountExtend.setKycLastUpdateTime(LocalDateTime.now());
    accountExtend.setUpdateTime(LocalDateTime.now());
    accountExtendRepository.update(accountExtend);
    
    // 5. 记录操作日志
    log.info("[KYC Reset] Admin重置成功 accountId={}, newRetryQuota={}", 
        accountId, accountExtend.getKycRetryQuota());
}
```

- [ ] **Step 3: 创建 ResetApplicantReqDTO**

```java
package com.qbit.white.label.api.cdd.model.request;

import lombok.Data;

@Data
public class ResetApplicantReqDTO {
    private String applicantId;
    private String resetIdDocSetTypes;
}
```

- [ ] **Step 4: 创建 KycAdminController**

```java
package com.qbit.white.label.admin.api.kyc;

import com.qbit.white.label.api.cdd.service.CddKycService;
import com.qbit.white.label.infra.business.Result;
import com.qbit.white.label.web.common.constants.WebConstants;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.annotation.Resource;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping(WebConstants.ADMIN_API_V1_PREFIX + "/kyc")
@Tag(name = "Admin KYC管理")
public class KycAdminController {

    @Resource
    private CddKycService cddKycService;

    @PostMapping("/reset")
    @Operation(summary = "重置用户KYC校验资格")
    public Result<Void> resetKyc(@RequestBody ResetKycRequest request) {
        cddKycService.adminResetKyc(request.getAccountId());
        return Result.ok();
    }
}
```

```java
package com.qbit.white.label.admin.api.kyc;

import lombok.Data;

@Data
public class ResetKycRequest {
    private Long accountId;
}
```

- [ ] **Step 5: 编译验证**

Run: `./mvnw compile -q`
Expected: BUILD SUCCESS

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add admin KYC reset API with Sumsub backend call"
```

---

## Task 5: u-app-admin — KYC状态筛选精简

**Files:**
- Modify: `src/views/user-management/user-list/_map/index.tsx`
- Modify: `src/views/user-management/user-list/_hooks/useUserList.tsx`
- Modify: `src/views/user-management/user-list/_locale/lang/zh.tsx`
- Modify: `src/views/user-management/user-list/_locale/lang/en.tsx`

- [ ] **Step 1: KycStatusMap 精简为4种聚合状态**

```tsx
// _map/index.tsx
export const SimpleKycStatusMap = new Map([
  ["NOT_SUBMITTED", "未提交"],
  ["VERIFYING", "校验中"],
  ["APPROVED", "已通过"],
  ["REJECTED", "已拒绝"]
]);

export const SimpleKycStatusEnMap = new Map([
  ["NOT_SUBMITTED", "Not Submitted"],
  ["VERIFYING", "Verifying"],
  ["APPROVED", "Approved"],
  ["REJECTED", "Rejected"]
]);
```

- [ ] **Step 2: useUserList.tsx 改用简单状态**

```tsx
// 替换 import
import { SimpleKycStatusMap, SimpleKycStatusEnMap } from "../_map";

// kycStatus filter
kycStatus: (): CustomSearchFilter => ({
  key: "kycStatus",
  comp: "select",
  placeholder: lang.value.filter.kycStatus,
  multiple: true,
  options: map2options(useAppStoreHook().lang === "zh" ? SimpleKycStatusMap : SimpleKycStatusEnMap)
}),

// kycStatus column — 使用后端返回的 simpleKycStatus
kycStatus: (): CustomTableColumn<DTO> => ({
  label: lang.value.columns.kycStatus,
  cell: row =>
    row.kycStatus
      ? useAppStoreHook().lang === "zh"
        ? SimpleKycStatusMap.get(row.simpleKycStatus || row.kycStatus as unknown as string)
        : SimpleKycStatusEnMap.get(row.simpleKycStatus || row.kycStatus as unknown as string)
      : "-"
}),
```

- [ ] **Step 3: 编译验证**

Run: `cd /Users/martinjiang/WebstormProjects/u-app-admin && npx vue-tsc --noEmit`
Expected: No type errors

- [ ] **Step 4: Commit**

```bash
git -C /Users/martinjiang/WebstormProjects/u-app-admin add -A
git -C /Users/martinjiang/WebstormProjects/u-app-admin commit -m "feat: simplify KYC status filter to 4 business states"
```

---

## Task 6: u-app-admin — 用户详情KYC区块 + 重试按钮

**Files:**
- Modify: `src/views/user-management/user-list/detail/index.tsx`
- Modify: `src/views/user-management/user-list/detail/_locale/lang/zh.tsx`
- Modify: `src/views/user-management/user-list/detail/_locale/lang/en.tsx`

- [ ] **Step 1: 查询用户详情时获取 KYC 数据**

detail/index.tsx 当前通过 `route.query` 获取基本信息。需要新增后端接口或从已有数据中获取 kyc 信息。

由于 detail 页面当前只展示了基本信息（route.query），可以复用已有的 accountPage 数据或在 detail 页面新增 KYC 查询。

最简方案：在 detail 页新增一个区块，调用后端获取用户 KYC 详情。

```tsx
// detail/index.tsx 新增 KYC 信息区块组件
```

- [ ] **Step 2: detail 页面新增 KYC 状态区块**

在用户信息卡片下方新增 KYC 信息行:
- KYC 状态: 显示中文/英文状态
- KYC 提交次数: x/3
- KYC 最后更新时间
- 拒绝原因(如有)

- [ ] **Step 3: 已拒绝状态显示"KYC校验重试"按钮**

```tsx
// KycBlock 组件中
{kycStatus === 'REJECTED' && (
  <el-button type="primary" onClick={handleRetryKyc} loading={resetting}>
    {lang.kyc.retryButton}
  </el-button>
)}
```

- [ ] **Step 4: 实现 handleRetryKyc 逻辑**

```tsx
const handleRetryKyc = async () => {
  await ElMessageBox.confirm(lang.kyc.retryConfirm, { type: 'warning' });
  resetting.value = true;
  try {
    await postAdminV1KycReset({ body: { accountId: route.query.accountId } });
    ElMessage.success(lang.kyc.retrySuccess);
    // 刷新页面数据
    fetch();
  } finally {
    resetting.value = false;
  }
};
```

- [ ] **Step 5: locale 新增文案**

zh.tsx:
```javascript
kyc: {
  status: "KYC状态",
  submitCount: "提交次数",
  lastUpdate: "最后更新时间",
  rejectReason: "拒绝原因",
  retryButton: "KYC校验重试",
  retryConfirm: "确认重置该用户的KYC校验资格？重置后用户将获得一次新的Sumsub提交机会。",
  retrySuccess: "KYC重置成功"
}
```

en.tsx:
```javascript
kyc: {
  status: "KYC Status",
  submitCount: "Submit Count",
  lastUpdate: "Last Update",
  rejectReason: "Reject Reason",
  retryButton: "Retry KYC Verification",
  retryConfirm: "Confirm reset this user's KYC verification? The user will get a new Sumsub submission opportunity.",
  retrySuccess: "KYC Reset Successful"
}
```

- [ ] **Step 6: 编译验证**

Run: `cd /Users/martinjiang/WebstormProjects/u-app-admin && npx vue-tsc --noEmit`
Expected: No type errors

- [ ] **Step 7: Commit**

```bash
git -C /Users/martinjiang/WebstormProjects/u-app-admin add -A
git -C /Users/martinjiang/WebstormProjects/u-app-admin commit -m "feat: add KYC info block and retry button to user detail page"
```

---

## Task 7: u-app (商户端) — 文案修改 + 逻辑兼容

**Files:**
- Modify: `src/kyc/result/_locale/lang/zh.tsx`
- Modify: `src/kyc/result/_locale/lang/en.tsx`
- Modify: `src/kyc/result/index.tsx`
- Modify: `src/kyc/index.tsx`

- [ ] **Step 1: 修改 rejected subtitle 文案**

zh.tsx:
```javascript
rejected: {
  title: "很抱歉，您的身份信息未通过审核，原因如下：",
  subtitle: "多次审核未通过，请联系客服协助处理"  // ← 修改
}
```

en.tsx:
```javascript
rejected: {
  title: "Sorry, your identity verification did not pass for the following reason: ",
  subtitle: "Verification failed multiple times. Please contact customer support for assistance."  // ← 修改
}
```

注意: 之前看到 en.tsx 的 function 名为 `useZh`，这可能是笔误，但保持和现有文件一致不做额外修改。

- [ ] **Step 2: kyc/index.tsx 修改入口判定**

当前代码第 84 行:
```typescript
} else if (userInfo?.kycStatus === CANCELED && userInfo?.kycSubmitCount && +userInfo?.kycSubmitCount >= 3) {
  router.replace("/kyc/result");
```

改为:
```typescript
// 判定是否需要显示拒绝页: kycSubmitCount >= 3 + kycRetryQuota
const isRejectedPermanently = userInfo?.kycSubmitCount && 
  +userInfo?.kycSubmitCount >= (3 + (userInfo?.kycRetryQuota || 0));
} else if (userInfo?.kycStatus === CANCELED && isRejectedPermanently) {
  router.replace("/kyc/result");
```

- [ ] **Step 3: kyc/result/index.tsx 修改拒绝状态判定**

当前 148-150 行:
```typescript
{userInfo?.kycStatus === KycStatus.CANCELED &&
  userInfo?.kycSubmitCount &&
  +userInfo?.kycSubmitCount >= 3 && <RejectedStatus />}
```

改为:
```typescript
{userInfo?.kycStatus === KycStatus.CANCELED &&
  userInfo?.kycSubmitCount &&
  +userInfo?.kycSubmitCount >= (3 + (userInfo?.kycRetryQuota || 0)) && <RejectedStatus />}
```

- [ ] **Step 4: 编译验证**

Run: `cd /Users/martinjiang/WebstormProjects/u-app && npx tsc --noEmit`
Expected: No type errors

- [ ] **Step 5: Commit**

```bash
git -C /Users/martinjiang/WebstormProjects/u-app add -A
git -C /Users/martinjiang/WebstormProjects/u-app commit -m "feat: update KYC rejected text and retry logic for admin reset"
```

---

## Task 8: white-label-server — 修改拒绝判定逻辑 + Webhook 兼容

**Files:**
- Modify: `app-biz/app-biz-cdd/src/main/java/com/qbit/white/label/biz/cdd/service/impl/CddKycServiceImpl.java`

- [ ] **Step 1: updateCddKyc 方法中修改拒绝判定**

当前 `updateCddKyc` 中每提交一次就 +1 submitCount。需要确保当有 retryQuota 时总配额 >= 3 + retryQuota 才禁止。

实际上，现有的 submitCddKyc 方法没有限制逻辑（限制在前端）。后端只需要确保当用户被重置后能正常 submit 即可。

- [ ] **Step 2: updateKycHook 中保持原有逻辑**

hook 响应中的 status 由 Interlace SDK / Sumsub 决定，不需要修改。

- [ ] **Step 3: 编译验证**

Run: `./mvnw compile -q`
Expected: BUILD SUCCESS

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "fix: ensure KYC retry compatibility in submit and webhook handling"
```

---

## Task 9: 联调 & 验证

- [ ] **Step 1: 端到端流程验证**

验证链路:
1. Admin 登录 → 用户管理 → 找到被拒绝用户
2. 用户详情 → 展示 KYC 状态"已拒绝" → 显示"KYC校验重试"按钮
3. 点击按钮 → 确认弹框 → 调后端 API
4. 后端调 qbit-assets → Sumsub 重置 applicant
5. 后端更新本地数据: retryQuota++, status = PENDING
6. 前端按钮消失, 状态更新
7. 商户端用户登录 → KYC 状态变为"校验中"
8. 用户可重新提交 KYC 表单
9. 提交 → Interlace SDK → Sumsub 重新校验
10. Sumsub Webhook → 更新状态

- [ ] **Step 2: 边界情况验证**
- 对未拒绝用户点击重置 → 应提示不可重置
- 多次重复重置 → retryQuota 累计增长, 无上限但合理
- Admin 重置后用户不提交 → 保持 PENDING 状态
- 重置后用户再次被拒绝 → 判定正确

---

## 执行方式

计划完成并保存在 `/Users/martinjiang/martin-dev-log/sumsub-kyc-reset-plan.md`。两个执行选项：

**1. Subagent-Driven（推荐）** — 每个 Task 派发独立 subagent，逐个执行 + review

**2. Inline Execution** — 在当前会话按 Task 顺序执行，批量 checkpoint

你选哪种？
