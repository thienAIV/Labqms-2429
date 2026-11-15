# Trạng thái chức năng v2.2.0-rc.1

- Dashboard chương, yêu cầu, liên kết tài liệu/hồ sơ: triển khai bằng migration 0016.
- Workflow tài liệu tách người soạn, rà soát, phê duyệt: RPC trong 0017.
- QR token và cảnh báo giới hạn số: RPC/trigger trong 0017.
- AI thật: Edge Function analyze-document, chỉ chạy khi quản trị viên cấu hình AI_API_URL, AI_API_KEY, AI_MODEL; kết quả luôn yêu cầu con người xử lý.
- Camera QR đa trình duyệt và ký số PKI công cộng: chưa công bố hoàn chỉnh; chữ ký xác nhận nội bộ đã có invalidation.
