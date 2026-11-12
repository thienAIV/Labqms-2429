# Báo cáo kiểm thử v1.2.0-rc.1

| Mã | Nội dung | Kết quả | Bằng chứng/Ghi chú |
|---|---|---|---|
| T01 | Production deployment | PASS | Vercel hiển thị Ready, Error Rate 0% theo ảnh nghiệm thu |
| T02 | Authentication UI | PASS | Đăng nhập/Đăng ký/Quên mật khẩu hiển thị trên Production |
| T03 | Frontend nhận Supabase env | PASS | Nút xem trước biến mất sau redeploy |
| T04 | ZIP integrity | PASS | `unzip -t` không lỗi |
| T05 | Static secret scan | PASS | Không phát hiện demo password/service role pattern |
| T06 | Production build từ bản bàn giao | BLOCKED | Sandbox npm install bị timeout và node_modules tải dở; không tuyên bố build cục bộ |
| T07 | Email ngoài domain bị chặn | BLOCKED | Cần tài khoản thử thật/Supabase Auth logs |
| T08 | Pending không đọc dữ liệu | BLOCKED | Cần phiên đăng nhập pending |
| T09 | RLS đa vai trò/tenant | BLOCKED | Cần 4 tài khoản thử và dữ liệu 2 laboratory |
| T10 | Private URL bị từ chối | BLOCKED | Cần file thật và Storage runtime |
| T11 | Signed URL hết hạn | NOT IMPLEMENTED | Chưa có Edge Function tạo signed URL có kiểm tra quyền |
| T12 | Phiên bản tài liệu bất biến | BLOCKED | Schema có; chưa test runtime |
| T13 | QR mở biểu mẫu | NOT IMPLEMENTED | Chỉ có schema QR, chưa có UI/route scanner |
| T14 | Chữ ký mất hiệu lực khi sửa | NOT IMPLEMENTED | Có schema snapshot hash, chưa có transaction/function |
| T15 | CAPA quá hạn | PASS một phần | Dashboard truy vấn due_date; chưa test dữ liệu thật |
| T16 | Realtime | NOT IMPLEMENTED | Chưa subscribe Supabase Realtime |
| T17 | Offline queue | NOT IMPLEMENTED | Có IndexedDB helper nhưng chưa nối vào form submission |
| T18 | Audit log | BLOCKED | Trigger/RPC có; chưa kiểm thử runtime |
| T19 | AI không tự phê duyệt | PASS ở schema | Quyết định yêu cầu decided_by/decided_at; AI runtime chưa triển khai |
| T20 | Không có dữ liệu demo Production | PASS | Dashboard truy vấn Supabase, màn hình trống dùng nhãn chưa triển khai |
| T21 | Responsive desktop/mobile | PASS quan sát | CSS breakpoint 1000/700px; Production hiển thị đúng ảnh desktop |
