# Hướng dẫn phục hồi migration
Không rollback trực tiếp trên production khi chưa sao lưu.

- 0005: trước khi có dữ liệu có thể xóa policies `storage_documents_*`, bucket `documents`, rồi các bảng `document_versions`, `documents` và enum `document_status`.
- 0004: xóa functions/policies liên quan assignments trước, sau đó xóa hai bảng assignments. Không xóa các cột organization_id nếu đã có dữ liệu.
- 0003: xóa function `has_permission`, policies, rồi `role_permissions` và `permissions`.

Trên production, ưu tiên migration sửa tiến về phía trước thay vì DROP bảng.
