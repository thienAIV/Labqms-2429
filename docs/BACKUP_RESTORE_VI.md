# Sao lưu và phục hồi

1. Trước release, tạo Supabase database backup/PITR theo gói đang sử dụng và xuất schema bằng Supabase CLI `supabase db dump --linked` trên máy quản trị.
2. Xuất riêng Storage object inventory và lưu bản sao file private theo chính sách bệnh viện.
3. Không phục hồi trực tiếp lên Production. Tạo project thử nghiệm, phục hồi database, cấu hình Auth URL và Storage, sau đó chạy bộ audit.
4. Kiểm tra số lượng profiles, criteria, documents, versions, records, evidence, audit logs và checksum file.
5. Chỉ chuyển Production sau khi người phụ trách phê duyệt biên bản phục hồi.
