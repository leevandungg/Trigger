

-- Trigger : Khi thêm hoặc cập nhập một chi tiết hóa đơn nào đó thì sẽ cập nhập lại số lượng và tính tổng số tiền đơn hàng 

ALTER TRIGGER trg_Add_Order_Detail ON CHITIETHOADON FOR INSERT, UPDATE AS
BEGIN
     DECLARE @SoLuongMua int, @SoLuongHienCo int, @GiaSP int, @MaSP NVARCHAR(50), @TongTienSP int, @MaDH NVARCHAR(50),
	 @SoLuongDaMua int, @MaCT NVARCHAR(50), @PTTT NVARCHAR(100), @TienPhi int, @ThanhTien int, @TongTienDH int

	 SELECT @SoLuongMua = SoLuong, @MaSP = MaSP, @MaDH = MaDH, @MaCT = MaCTHD FROM inserted

	 SELECT @SoLuongDaMua = SoLuong FROM deleted WHERE MaCTHD = @MaCT

	 SELECT @PTTT = PTTT FROM DONHANG WHERE MaDH = @MaDH

	 SELECT @TienPhi = PhiTT FROM PAYMENT WHERE MaPTTT = @PTTT

	 SELECT @SoLuongHienCo = SoluongSP, @GiaSP = GiaSP FROM PRODUCT WHERE MaSP = @MaSP

	 IF(@SoLuongDaMua IS NULL)
	 SET @SoLuongDaMua = 0

	 IF(@SoLuongMua > @SoLuongHienCo + @SoLuongDaMua)
	 BEGIN
	    PRINT N'Số lượng sản phẩm trong kho không đủ để mua hàng.'
		ROLLBACK TRAN
	 END

	 UPDATE PRODUCT SET SoluongSP = @SoLuongHienCo - @SoLuongMua + @SoLuongDaMua WHERE MaSP = @MaSP

	 UPDATE CHITIETHOADON SET @TongTienSP = ThanhTien = @GiaSP * @SoLuongMua WHERE MaCTHD = @MaCT


     UPDATE DONHANG SET @TongTienDH = TongTien = TongTien + @TongTienSP WHERE MaDH = @MaDH

	 SELECT @ThanhTien = SUM(ThanhTien) FROM CHITIETHOADON WHERE MaDH = @MaDH
	
	 IF(@TongTienDH != @ThanhTien + @TienPhi) 

	 UPDATE DONHANG SET @TongTienDH = TongTien = TongTien + @TienPhi WHERE MaDH = @MaDH

END

GO

DELETE FROM DONHANG WHERE MaDH = 'DH006'

INSERT INTO DONHANG VALUES('DH006','2022-03-08',N'Đang giao',0,'KH003','TT01')

INSERT INTO CHITIETHOADON VALUES ('CT006',3,20000,0,'DH006','SP001')

INSERT INTO CHITIETHOADON VALUES ('CT007',2,100000,0,'DH006','SP002')

DELETE FROM CHITIETHOADON WHERE MaCTHD = 'CT007' 

DELETE FROM CHITIETHOADON WHERE MaCTHD = 'CT006' 

GO

--Trigger: Tạo Trigger khi ta order 1 sản phẩm thì tiến hành cập nhật SoluongSP của bảng PRODUCT điều kiện số lượng đặt hàng của bảng CHITIETHOADON <= số lượng sản phẩm của bảng PRODUCT, nếu không thoả mãn điều kiện sẽ ngừng INSERT
 
CREATE TRIGGER trg_soluongdamua ON CHITIETHOADON
FOR INSERT
AS
DECLARE @MaSP VARCHAR(10)
DECLARE @SoLuong int
DECLARE @SoluongSP int
SELECT @SoLuong = SoLuong, @MaSP = MaSP FROM inserted
SELECT @SoluongSP = SoluongSP - @SoLuong FROM PRODUCT WHERE MaSP = @MaSP
IF @SoluongSP + @SoLuong >= @SoLuong
UPDATE PRODUCT SET SoluongSP = @SoluongSP WHERE MaSP = @MaSP
ELSE
PRINT 'Khong du so luong.'
ROLLBACK TRANSACTION
----
----Thực thi
INSERT CHITIETHOADON VALUES ('CT006',23,120000,360000,'DH001','SP003')
--SP còn 0
INSERT CHITIETHOADON VALUES ('CT006',24,120000,360000,'DH001','SP003')
--SP báo không đủ số lượng


--Event: Tạo 1 event cứ mỗi 1 tháng (Cho thời hạn là 1 năm tức 12 tháng) thì công ty sẽ cập nhật SoluongSP của bảng PRODUCT 1 lần với SoluongSP cố định là 100 trên mỗi SP. Khi kiểm thử cứ mỗi 5 giây sẽ cập nhật 1 sản phẩm và kéo dài 15s để thầy dễ xem. Ví dụ tháng 1 chạy chương trình thì tới tháng 12 sẽ là lần cuối nhận chương trình và kết thúc.
 
CREATE EVENT NHAPHANG
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP
ENDS CURRENT_TIMESTAMP + INTERVAL 11 MONTH
DO
UPDATE product SET SoluongSP = SoluongSP + 100;
 
--Ví dụ kiểm thử.

CREATE EVENT NHAPHANG
ON SCHEDULE EVERY 10 SECOND
STARTS CURRENT_TIMESTAMP
ENDS CURRENT_TIMESTAMP + INTERVAL 50 SECOND
DO
UPDATE product SET SoluongSP = SoluongSP + 1;
    
-- Trigger : Khi khách hàng hủy đơn hàng thì số lượng sản phẩm được cập nhập
ALTER TRiGGER trg_huydathang2 on dbo.DONHANG for UPDATE
AS BEGIN
DECLARE @TrangThai nvarchar(100), @SoLuong int, @MaDH NVARCHAR(100), @MaSP NVARCHAR(100), @TongDon int
SELECT @TrangThai = Trangthai, @MaDH = MaDH FROM inserted
SELECT @TongDon = COUNT(*) FROM CHITIETHOADON WHERE MaDH = @MaDH
IF(@TrangThai = N'Đã hủy')
BEGIN
WHILE (@TongDon > 0)
BEGIN
SELECT @SoLuong = SoLuong, @MaSP = MaSP FROM CHITIETHOADON WHERE MaDH = @MaDH ORDER BY MaSP DESC OFFSET (@TongDon - 1)
ROWS FETCH NEXT 1 ROWS ONLY;
UPDATE PRODUCT SET SoluongSP = SoluongSP + @SoLuong WHERE MaSP = @MaSP;
SET @TongDon = @TongDon - 1;
END
END
END
-- test
UPDATE DONHANG SET Trangthai = N'Đã hủy' where MaDH = 'DH006'
-- Thêm test
INSERT INTO CHITIETHOADON VALUES ('CT006',3,20000,0,'DH006','SP001')

INSERT INTO CHITIETHOADON VALUES ('CT007',2,100000,0,'DH006','SP002')

-- Trigger : Khi thêm một sản phẩm thì số lượng không quá 50
CREATE TRIGGER LIMIT_QUANTITY ON PRODUCT FOR INSERT
AS
DECLARE @SoLuong int
SELECT @SoLuong = SoluongSP FROM inserted
IF(@SoLuong > 50)
BEGIN
PRINT N'Số lượng sản phẩm lớn hơn 50'
ROLLBACK TRAN
END

-- Kiểm thử
INSERT INTO PRODUCT VALUES ('SP005',N'Điện thoại',N'Điện thoại thông minh đời mới',1000000000,50);

DELETE FROM PRODUCT WHERE MaSP = 'SP005'

--- Trigger: Tạo trigger khi tiến hành cập nhật  SoluongSP của bảng PRODUCT thì số lượng sản phẩm >= số lượng đặt hàng của bảng
CREATE TRIGGER Tr_update
    ON dbo.PRODUCT
FOR UPDATE 
AS 
    IF(SELECT SUM(dbo.PRODUCT.SoluongSP)
        FROM dbo.PRODUCT INNER JOIN Inserted 
            ON Inserted.MaSP = PRODUCT.MaSP)
            <
        (SELECT SUM(dbo.CHITIETHOADON.SoLuong)
            FROM dbo.CHITIETHOADON INNER JOIN Inserted 
                ON Inserted.MaSP = CHITIETHOADON.MaSP)
BEGIN 
    PRINT N'Tổng số lượng nhập nhỏ hơn số lượng đặt hàng'
    ROLLBACK TRAN
END
ELSE PRINT N'Update sản phẩm thành công'
 
---
  UPDATE dbo.PRODUCT
  SET SoluongSP = 30 WHERE MaSP = 'SP001'

 

  SELECT * FROM dbo.PRODUCT
---
  UPDATE dbo.PRODUCT
  SET SoluongSP = 10 WHERE MaSP = 'SP001'

 

 SELECT * FROM dbo.PRODUCT

 

-- Event: Tạo 1 event cứ mỗi 15 ngày sẽ cập nhật lại  GiaSP của bảng PRODUCT 1 lần 
-- với GiaSP cố định là 2000 trên mỗi SP. 
 
create EVENT eve_update   
ON SCHEDULE EVERY 15 day
STARTS CURRENT_TIMESTAMP
ENDS CURRENT_TIMESTAMP + INTERVAL 1 MONTH
    DO
      UPDATE PRODUCT SET GiaSP = GiaSP + 2000;
      
    select * from product;

-- Trigger : Khi thêm một chi tiết đơn hàng thì số lượng lớn hơn 0 và mã đơn hàng có trong đơn hàng
CREATE TRIGGER THEM1
ON CHITIETHOADON
FOR INSERT
AS
begin
DECLARE @SOTIEN INT,@SOLUONG INT, @KIEMTRA NVARCHAR,@GIA INT
SELECT @GIA = GiaSPmua FROM inserted
SELECT @SOLUONG = SoLuong FROM inserted
SELECT @KIEMTRA = MaDH FROM INSERTED
IF (@SOLUONG <0 ) AND (@KIEMTRA NOT IN ( SELECT MaDH FROM DONHANG) )
ROLLBACK TRAN
END
GO  
-- Kiểm thử
INSERT INTO CHITIETHOADON VALUES ('CT008',3,60000,0,'DH006','SP001')
INSERT INTO CHITIETHOADON VALUES ('CT009',2,500000,0,'DH006','SP002')

