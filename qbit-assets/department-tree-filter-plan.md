# 部门销售树接口 — POST /api/admin/system/department/sales/tree

## Context

当前系统有两个相关接口：
- `POST /api/admin/system/department/sales` — 返回扁平的销售部门列表
- `POST /api/admin/employees/sales` — 员工列表查询，需传 departmentId

现在新增 **销售部门树接口**，返回树形结构 + 每个部门的成员列表 + `iShow` 可见性标记。

### 人员角色（简化为两种）

| 角色 | 可见范围 |
|------|---------|
| 非销售 | 全量树，所有节点和成员 isShow=true |
| 销售主管 | 能看到的子树下所有成员 isShow=true |
| 普通销售 | 只看自己 isShow=true |

**关键：** 销售主管和普通销售都用 `common-sales` 角色码，没有额外的"主管"角色码。区分方式：
- 通过用户所属部门在树中的位置决定可见范围
- 销售主管：所属部门及所有子孙部门的成员 → isShow=true
- 普通销售：仅自己 → isShow=true

**后续扩展：** 每个部门和成员都有 `iShow` 字段，后续可按需调整可见性粒度。

## 数据模型

```
User 实体关键字段（登录后填充，@TableField(exist=false)）：
  - systemSales          : Boolean           — 是否是销售（role code = "common-sales"）
  - systemDepartmentIds  : Set<Long>         — 所属部门 ID
  - deptDataPermissionRespDTO : DeptDataPermissionRespDTO

关联表：system_user_department(userId, mapper 已有 selectUserIdsByDepartmentId)
```

## 修改文件清单

### 1. DepartmentUserVO.java（新建）

**路径:** `qbit-core/src/main/java/com/qbit/common_all/system/domain/vo/DepartmentUserVO.java`

```java
package com.qbit.common_all.system.domain.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

/**
 * 部门成员信息
 * @author martinjiang
 */
@Data
public class DepartmentUserVO {
    
    @Schema(description = "用户ID")
    private String userId;
    
    @Schema(description = "用户昵称")
    private String nickname;
    
    @Schema(description = "是否可见")
    private Boolean iShow;
}
```

### 2. DepartmentVO.java

**路径:** `qbit-core/src/main/java/com/qbit/common_all/system/domain/vo/DepartmentVO.java`

新增字段：

```java
@Schema(description = "是否可见")
private Boolean iShow;

@Schema(description = "部门成员列表")
private List<DepartmentUserVO> members;
```

### 3. AdminDepartmentController.java

**路径:** `qbit-core/src/main/java/com/qbit/admin/system/controller/AdminDepartmentController.java`

新增端点：

```java
@PostMapping("/sales/tree")
@Operation(description = "查询销售部门树", summary = "销售部门树形结构")
public Result<List<DepartmentVO>> salesDepartmentTree() {
    return Result.ok(systemDepartmentService.salesDepartmentTree());
}
```

### 4. SystemDepartmentService.java

**路径:** `qbit-core/src/main/java/com/qbit/common_all/system/service/SystemDepartmentService.java`

新增 `salesDepartmentTree()` 方法，逻辑：

```
1. User user = UserContext.getUser()
2. List<DepartmentVO> allNodes = getFullDepartmentTree()   // 全量递归树
3. if (!isSales) → 全员 isShow=true，加载所有成员
4. else → 根据 user.systemDepartmentIds 定位用户位置
5. 遍历树，为每个部门加载成员，设置 isShow
6. return allNodes
```

**isShow 计算规则：**
- 非销售：所有节点 isShow=true
- 销售主管：用户所属部门 + 所有子孙部门的成员 isShow=true
- 普通销售：仅自己 isShow=true

**判断销售主管 vs 普通销售：**
- 当前阶段：都按"销售主管"逻辑处理（所属部门及子孙的成员都可见）
- 后续如果要做区分，可以在 MemberVO 或 DepartmentVO 上增加角色标记字段

### 5. 成员数据源

复用已有的 `SystemUserDepartmentMapper.selectUserIdsByDepartmentId(Long departmentId)` 查询部门下所有 userId。

用户昵称通过 `userMapper.selectById(userId)` 获取，数据量小（~20人），N+1 查询无性能问题。

## 返回示例

普通销售属于"销售1组"(deptId=100)：

```json
[
  {
    "id": 99, "name": "销售部", "parentId": null,
    "iShow": false,
    "children": [
      {
        "id": 101, "name": "销售一部",
        "iShow": false,
        "children": [
          {
            "id": 100, "name": "销售1组",
            "iShow": true,
            "members": [
              { "userId": "A", "nickname": "张三", "iShow": true },
              { "userId": "B", "nickname": "李四", "iShow": false }
            ],
            "children": []
          }
        ]
      }
    ]
  }
]
```

销售主管属于"销售一部"(deptId=101)：

```json
[
  {
    "id": 99, "name": "销售部",
    "iShow": true,
    "children": [
      {
        "id": 101, "name": "销售一部",
        "iShow": true,
        "children": [
          {
            "id": 100, "name": "销售1组",
            "iShow": true,
            "members": [
              { "userId": "A", "nickname": "张三", "iShow": true },
              { "userId": "B", "nickname": "李四", "iShow": true }
            ]
          }
        ]
      }
    ]
  }
]
```

## 验证方式

1. **编译检查:** `mvn compile -q -pl qbit-core -am`
2. **API 测试:**
   - 非销售角色登录 → 全量树，所有节点和成员 isShow=true
   - 普通销售登录 → 仅在归属部门及祖先路径上 isShow=true
   - 销售主管登录 → 其部门及所有子孙节点 isShow=true
3. **回归:** 确保 `/list` 和 `/sales` 旧接口不受影响
