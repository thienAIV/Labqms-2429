# Bàn giao
- Dữ liệu pháp lý: chỉ tiêu chí `verified`, có nguồn/người/ngày xác minh mới được tính điểm.
- Storage: bucket documents private; mở file qua Edge Function signed URL.
- Tài khoản mới pending; Admin phê duyệt bằng RPC.
- Audit và vô hiệu hóa chữ ký đã được kiểm thử runtime trên Production ở migrations 0013–0014.
- Dữ liệu thử cần xóa mềm sau nghiệm thu: TEST-PERSIST-001, NC-TEST-001, SIGNED-URL-TEST-001.
