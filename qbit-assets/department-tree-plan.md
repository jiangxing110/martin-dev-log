# 部门销售树接口 — POST /api/admin/system/department/sales/tree

## Context

当前系统有两个相关接口：
- `POST /api/admin/system/department/sales` — 返回扁平的销售部门列表（按 data_scope_type 过滤 ID）
- `POST /api/admin/employees/sales` — 员工列表查询，需传 departmentId

现在新增 **销售部门树接口**，要求：
1. 返回完整的 **树形结构**（递归 children）
2. 每个部门节点下挂 `members` 数组，包含该部门的成员 userId/name/isShow
3. 部门和用户都有 `iShow` 标记字段，表示对该登录用户是否可见
4. 非销售 → 全量树 + isShow=true；销售 → 按 data_scope_type 限制 isShow

## 数据模型

```
User 实体关键字段（登录后填充，@TableField(exist=false)）：
  - systemSales          : Boolean           — 是否是销售
  - systemDepartmentIds  : Set<Long>         — 所属部门 ID
  - deptDataPermissionRespDTO.deptIds    : Set<Long>       — 可查看的部门 ID
  - deptDataPermissionRespDTO.all        : Boolean          — 是否可见全部
  - deptDataPermissionRespDTO.self       : Boolean          — 是否仅自己

DataScopeTypeEnum（角色维度）：
  ALL(1), DEPT_CUSTOM(2), DEPT_ONLY(3), DEPT_AND_CHILD(4), SELF(5)

关联表：system_user_department(userId, departmentId)
已有 Mapper：SystemUserDepartmentMapper.selectUserIdsByDepartmentId(Long)
```

## 修改文件清单

### 1. DepartmentVO.java

**路径:** `qbit-core/src/main/java/com/qbit/common_all/system/domain/vo/DepartmentVO.java`

增加两个字段：

```java
@Schema(description = "是否可见")
private Boolean iShow;

@Schema(description = "部门成员列表")
private List<MemberVO> members;
```

新增 MemberVO：

```java
@Data
public class MemberVO {
    @Schema(description = "用户ID")
    private String userId;
    
    @Schema(description = "用户昵称")
    private String nickname;
    
    @Schema(description = "是否可见")
    private Boolean iShow;
}
```

### 2. AdminDepartmentController.java

**路径:** `qbit-core/src/main/java/com/qbit/admin/system/controller/AdminDepartmentController.java`

新增端点：

```java
@PostMapping("/sales/tree")
@Operation(description = "查询销售部门树", summary = "销售部门树形结构")
public Result<List<DepartmentVO>> salesDepartmentTree() {
    return Result.ok(systemDepartmentService.salesDepartmentTree());
}
```

### 3. SystemDepartmentService.java

**路径:** `qbit-core/src/main/java/com/qbit/common_all/system/service/SystemDepartmentService.java`

核心方法 `salesDepartmentTree()` 逻辑：

```
1. User user = UserContext.getUser()
2. List<DepartmentVO> allNodes = getFullDepartmentTree()     // 全量递归树
3. if (!user.getSystemSales()) → 全员 isShow=true, 加载所有成员
4. else → 根据 deptDataPermissionRespDTO 计算 visibleDeptIds
5. attachMembersAndIShow(allNodes, userId, visibleDeptIds)   // 遍历设置
6. return allNodes
```

`visibleDeptIds` 计算规则：
| DataScopeType | visibleDeptIds |
|---|---|
| ALL | 已在上层分支处理，不进入这里 |
| DEPT_AND_CHILD | 从 user.systemDepartmentIds 出发，向上追溯父级祖先 + 向下展开所有子孙 |
| DEPT_ONLY | 等于 user.systemDepartmentIds |
| DEPT_CUSTOM | 角色的 dataScopeDeptIds + user.systemDepartmentIds |
| SELF | 空集（只看自己，member 级别判断时只用 userId 匹配） |

`attachMembersAndIShow(node, currentUserId, visibleDeptIds)`：
- 对每个部门节点：查询 `selectUserIdsByDepartmentId(node.id)` 获取成员列表
- 每个成员的 isShow = (`visibleDeptIds` 包含该部门 OR 成员userId == currentUserId)
- 节点本身的 isShow = `visibleDeptIds` 包含 node.id（或子孙有 isShow=true）

### 4. SystemDepartmentMapper.xml（如需）

如果当前没有递归查整棵树的查询，可以复用已有的 `selectAllDepartment` 递归查询或 `selectAllDepartmentId` + Java 构建树。无需新增 SQL。

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

## 验证方式

1. **编译检查:** `mvn compile -q -pl qbit-core -am`
2. **API 测试:**
   - 非销售角色登录 → 全量树，所有节点和成员 isShow=true
   - 普通销售登录 → 仅在归属部门及祖先路径上 isShow=true
   - 负责人(DEPT_AND_CHILD)登录 → 其部门及子孙节点 isShow=true
3. **回归:** 确保 `/list` 和 `/sales` 旧接口不受影响
