# Triển khai

1. GitHub repository kết nối Vercel, framework Vite, root `./`.
2. Cấu hình hai biến trong `docs/ENVIRONMENT.md` cho Production/Preview/Development.
3. Chạy migration theo thứ tự 0001 đến 0010. Không chạy lại file đã triển khai; dùng `docs/SUPABASE_AUDIT.sql` để kiểm kê.
4. Authentication bật email confirmation; Site URL và Redirect URL trỏ về domain Production.
5. Bucket `documents` phải private.
6. Chỉ triển khai production sau khi test đa tài khoản và backup/restore môi trường thử nghiệm đạt.
