# Hướng dẫn quản trị

- Tài khoản mới ở trạng thái `pending`; chỉ Super Admin/Lab Admin phê duyệt.
- Trước khi phê duyệt, Admin phải có `organization_id` và `laboratory_id`.
- Chỉ tiêu chí `verified` có nguồn, người xác minh và thời điểm xác minh mới được dùng trong đánh giá.
- Không sửa trực tiếp phiên bản tài liệu đã phê duyệt; tạo phiên bản mới.
- Không dùng public URL cho tài liệu. Chỉ cấp signed URL sau khi kiểm tra quyền.
- Không nhập dữ liệu người bệnh vào AI khi chưa có phê duyệt bảo mật.
