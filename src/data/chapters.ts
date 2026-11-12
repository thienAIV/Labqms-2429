export type Chapter={id:number;roman:string;name:string};
export const chapters:Chapter[]=[
[1,'I','TỔ CHỨC VÀ QUẢN LÝ PHÒNG XÉT NGHIỆM'],[2,'II','QUẢN LÝ TÀI LIỆU VÀ HỒ SƠ'],[3,'III','QUẢN LÝ NHÂN SỰ'],[4,'IV','CUNG CẤP DỊCH VỤ VÀ QUẢN LÝ KHÁCH HÀNG'],[5,'V','QUẢN LÝ TRANG THIẾT BỊ'],[6,'VI','ĐÁNH GIÁ NỘI BỘ'],[7,'VII','QUẢN LÝ MUA SẮM, TRANG THIẾT BỊ, VẬT TƯ, HÓA CHẤT VÀ SINH PHẨM'],[8,'VIII','QUẢN LÝ QUÁ TRÌNH XÉT NGHIỆM'],[9,'IX','QUẢN LÝ THÔNG TIN'],[10,'X','XÁC ĐỊNH SỰ KHÔNG PHÙ HỢP, HÀNH ĐỘNG KHẮC PHỤC VÀ HÀNH ĐỘNG PHÒNG NGỪA'],[11,'XI','CẢI TIẾN LIÊN TỤC'],[12,'XII','CƠ SỞ VẬT CHẤT VÀ AN TOÀN']
].map(([id,roman,name])=>({id:id as number,roman:roman as string,name:name as string}));
