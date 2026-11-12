## Changelog

### 1.2.0-rc.1
- Bổ sung provenance cho tiêu chí, review/approval tài liệu và hardening audit.
- Bổ sung CSV trong private bucket.
- Bổ sung tài liệu triển khai, quản trị, người dùng, ma trận quyền, audit và test report.
- Ghi rõ các module chưa triển khai, không trình bày như đã hoạt động.

# Changelog
## 1.0.0-rc.1
- Hoàn thiện schema hồ sơ, đánh giá, CAPA, biểu mẫu, QR, thông báo và AI review.
- Thêm PWA service worker và IndexedDB offline queue.
- Thêm kiểm tra bảo mật tĩnh và checklist phát hành.
- Đánh dấu release candidate, chưa tuyên bố production trước kiểm thử RLS thực tế.

## 0.3.0
- Thêm ma trận quyền theo hành động và hàm `has_permission`.
- Thêm phân quyền theo phòng xét nghiệm, chương và tiêu chí.
- Thêm quản lý tài liệu, phiên bản bất biến, checksum và private Storage bucket.
- Thêm Storage policies theo organization/laboratory và giới hạn file 50 MB.
- Thêm hướng dẫn rollback an toàn.

## 0.2.0
- Authentication thật với đăng nhập, đăng ký và quên mật khẩu.
- Chặn email ngoài @sungrouphospital.com ở frontend và trigger PostgreSQL.
- Tạo profile pending tự động sau đăng ký.
- Màn hình chờ phê duyệt và tài khoản bị khóa.
- Hàm khởi tạo Super Admin đầu tiên có khóa giao dịch chống tranh chấp.
- Hàm phê duyệt người dùng có kiểm tra vai trò.
- Audit log chỉ Admin được đọc, người dùng thường không có policy ghi/sửa/xóa.
- Tải 12 chương từ Supabase sau khi tài khoản được approved; fallback an toàn khi xem trước.
