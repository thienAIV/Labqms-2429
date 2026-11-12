# Checklist phát hành
- [ ] Chạy tuần tự migration 0001 đến 0008 trên môi trường thử nghiệm.
- [ ] Cấu hình VITE_SUPABASE_URL và VITE_SUPABASE_PUBLISHABLE_KEY tại Vercel.
- [ ] Bật Email confirmation và đặt Site URL/Redirect URLs.
- [ ] Tạo Super Admin đầu tiên, sau đó vô hiệu hóa luồng claim trong quy trình vận hành.
- [ ] Kiểm thử pending, viewer, staff, chapter_lead, lab_admin và tenant isolation.
- [ ] Kiểm tra bucket documents là private và public URL bị từ chối.
- [ ] Xác nhận dữ liệu 2429 trước khi nhập và tính điểm.
- [ ] Thực hành sao lưu, phục hồi trên project thử nghiệm.
- [ ] Chỉ phê duyệt production sau khi test bảo mật đạt.
