# Quy trình nhập dữ liệu pháp lý QĐ 2429

1. Trích xuất từng tiêu chí với mã in trên PDF, mã chuẩn hóa, chương, điểm, dấu sao, trang và hash đoạn nguồn.
2. Hai lượt đối chiếu độc lập với PDF scan.
3. Mỗi dòng chỉ chuyển `approved` sau khi đối chiếu.
4. Validator bắt buộc đúng 12 chương, 169 tiêu chí, 268 điểm và tổng từng chương.
5. Chỉ Super Admin được phê duyệt toàn bộ batch.
6. Trước phê duyệt, dữ liệu staging không tham gia dashboard chính thức hay tính điểm.
7. Mã in bất thường tại Chương V được giữ ở `source_code`; `normalized_code` dùng 5.1–5.19 và phải có ghi chú đối chiếu.
