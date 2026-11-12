import { FormEvent, useEffect, useMemo, useState } from 'react';
import { AlertTriangle, BookOpen, FlaskConical, LogOut, Search, ShieldCheck, Wifi } from 'lucide-react';
import type { Session } from '@supabase/supabase-js';
import { chapters as fallbackChapters, Chapter } from './data/chapters';
import { supabase, supabaseConfigured } from './lib/supabase';

type View='home'|'dashboard'|'documents'|'capa'|'users';
type Profile={id:string;email:string;full_name:string|null;status:'pending'|'approved'|'suspended';role:string};
type AuthMode='login'|'register'|'reset';

export default function App(){
 const [session,setSession]=useState<Session|null>(null);
 const [profile,setProfile]=useState<Profile|null>(null);
 const [loading,setLoading]=useState(true);
 const [view,setView]=useState<View>('home');
 const [query,setQuery]=useState('');
 const [selected,setSelected]=useState<Chapter|null>(null);
 const [chapterData,setChapterData]=useState<Chapter[]>(fallbackChapters);
 const [preview,setPreview]=useState(false);

 useEffect(()=>{
  if(!supabase){setLoading(false);return;}
  supabase.auth.getSession().then(({data})=>{setSession(data.session);setLoading(false)});
  const {data}=supabase.auth.onAuthStateChange((_event,next)=>setSession(next));
  return()=>data.subscription.unsubscribe();
 },[]);
 useEffect(()=>{
  if(!supabase||!session){setProfile(null);return;}
  supabase.from('profiles').select('id,email,full_name,status,role').eq('id',session.user.id).single()
   .then(({data})=>setProfile(data as Profile|null));
 },[session]);
 useEffect(()=>{
  if(!supabase||profile?.status!=='approved')return;
  supabase.from('chapters').select('id,roman,name').order('id').then(({data})=>{
   if(data?.length===12)setChapterData(data as Chapter[]);
  });
 },[profile]);
 const shown=useMemo(()=>chapterData.filter(c=>(`CHƯƠNG ${c.roman} ${c.name}`).toLowerCase().includes(query.toLowerCase())),[query,chapterData]);
 if(loading)return <div className="splash"><FlaskConical/><b>Đang kiểm tra phiên đăng nhập...</b></div>;
 if(!session&&!preview)return <AuthScreen onPreview={()=>setPreview(true)}/>;
 if(session&&profile&&profile.status!=='approved')return <ApprovalGate profile={profile} onSignOut={()=>supabase?.auth.signOut()}/>;
 const displayName=preview?'Bản xem trước':profile?.full_name||session?.user.email||'Người dùng';
 return <div className="app"><header><div className="brand"><FlaskConical/>LabQMS 2429</div><div className="search"><Search size={18}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="Tìm tiêu chí, tài liệu, hồ sơ, CAPA..."/></div><span className={`sync ${supabaseConfigured?'ok':'warn'}`}><Wifi size={15}/>{supabaseConfigured?'Supabase đã cấu hình':'Chế độ xem trước'}</span><span className="userName">{displayName}</span><button className="icon" onClick={()=>preview?setPreview(false):supabase?.auth.signOut()} aria-label="Đăng xuất"><LogOut/></button></header>
 <aside>{([['home','12 chương'],['dashboard','Dashboard'],['documents','Tài liệu & hồ sơ'],['capa','CAPA'],['users','Người dùng']] as [View,string][]).map(([id,label])=><button className={view===id?'active':''} onClick={()=>setView(id)} key={id}>{label}</button>)}<div className="security"><ShieldCheck/> RLS kiểm soát truy cập tại PostgreSQL</div></aside>
 <main>{view==='home'?<><div className="title"><div><small>QUYẾT ĐỊNH 2429/QĐ-BYT</small><h1>12 chương quản lý chất lượng</h1><p>Dữ liệu nghiệp vụ chưa xác minh không được dùng để tính điểm.</p></div></div><div className="notice"><AlertTriangle/><div><b>Trạng thái dữ liệu pháp lý</b><br/>Chưa nhập tiêu chí. Chỉ nhập sau khi quản trị viên đối chiếu phụ lục chính thức.</div></div><div className="grid">{shown.map(c=><button className="chapter" onClick={()=>setSelected(c)} key={c.id}><div className="chapterTop"><BookOpen/><span>Chưa triển khai</span></div><h2>CHƯƠNG {c.roman}. {c.name}</h2><dl><div><dt>Người phụ trách</dt><dd>Chưa phân công</dd></div><div><dt>Điểm</dt><dd>Chưa đánh giá</dd></div><div><dt>Minh chứng</dt><dd>Chưa có dữ liệu</dd></div><div><dt>CAPA</dt><dd>Chưa có dữ liệu</dd></div></dl></button>)}</div></>:<EmptyModule name={view}/>}</main>
 {selected&&<div className="modalWrap" onClick={()=>setSelected(null)}><section className="modal" onClick={e=>e.stopPropagation()}><button className="close" onClick={()=>setSelected(null)}>×</button><small>CHƯƠNG {selected.roman}</small><h2>{selected.name}</h2><div className="notice"><AlertTriangle/><div><b>Chưa xác minh, cần quản trị viên đối chiếu phụ lục chính thức.</b><p>Hệ thống tách riêng nội dung nguyên văn, bằng chứng văn bản yêu cầu, bằng chứng gợi ý và khuyến nghị AI.</p></div></div></section></div>}
 </div>
}

function AuthScreen({onPreview}:{onPreview:()=>void}){
 const[mode,setMode]=useState<AuthMode>('login');const[email,setEmail]=useState('');const[password,setPassword]=useState('');const[fullName,setFullName]=useState('');const[error,setError]=useState('');const[message,setMessage]=useState('');const[busy,setBusy]=useState(false);
 async function submit(e:FormEvent){e.preventDefault();setError('');setMessage('');if(!email.toLowerCase().endsWith('@sungrouphospital.com'))return setError('Chỉ chấp nhận email @sungrouphospital.com');if(!supabase)return setError('Chưa cấu hình Supabase trên Vercel.');setBusy(true);
  if(mode==='reset'){const{error}=await supabase.auth.resetPasswordForEmail(email,{redirectTo:window.location.origin});setBusy(false);return error?setError(error.message):setMessage('Đã gửi email đặt lại mật khẩu.');}
  if(password.length<8){setBusy(false);return setError('Mật khẩu phải có ít nhất 8 ký tự.');}
  if(mode==='register'){const{error}=await supabase.auth.signUp({email,password,options:{data:{full_name:fullName}}});setBusy(false);return error?setError(error.message):setMessage('Đã gửi đăng ký. Hãy xác thực email, sau đó chờ quản trị viên phê duyệt.');}
  const{error}=await supabase.auth.signInWithPassword({email,password});setBusy(false);if(error)setError('Đăng nhập không thành công. Kiểm tra email, mật khẩu và trạng thái xác thực.');
 }
 return <div className="login"><form onSubmit={submit}><FlaskConical size={46}/><h1>LabQMS 2429</h1><p>Quản lý chất lượng phòng xét nghiệm y học</p><div className="modeTabs"><button type="button" className={mode==='login'?'selected':''} onClick={()=>setMode('login')}>Đăng nhập</button><button type="button" className={mode==='register'?'selected':''} onClick={()=>setMode('register')}>Đăng ký</button></div>{mode==='register'&&<label>Họ và tên<input value={fullName} onChange={e=>setFullName(e.target.value)} required/></label>}<label>Email công việc<input value={email} onChange={e=>setEmail(e.target.value)} type="email" placeholder="ten@sungrouphospital.com" required/></label>{mode!=='reset'&&<label>Mật khẩu<input value={password} onChange={e=>setPassword(e.target.value)} type="password" required/></label>}{error&&<div className="error">{error}</div>}{message&&<div className="success">{message}</div>}<button disabled={busy} type="submit">{busy?'Đang xử lý...':mode==='login'?'Đăng nhập':mode==='register'?'Gửi đăng ký':'Gửi email đặt lại mật khẩu'}</button><button type="button" className="textButton" onClick={()=>setMode(mode==='reset'?'login':'reset')}>{mode==='reset'?'Quay lại đăng nhập':'Quên mật khẩu?'}</button>{!supabaseConfigured&&<button type="button" className="secondary" onClick={onPreview}>Mở bản xem trước an toàn</button>}<small>Tài khoản mới mặc định chờ phê duyệt. Không có khóa bí mật trong frontend.</small></form></div>
}
function ApprovalGate({profile,onSignOut}:{profile:Profile;onSignOut:()=>void}){return <div className="login"><section className="gate"><ShieldCheck size={52}/><h1>{profile.status==='suspended'?'Tài khoản đã bị khóa':'Chờ quản trị viên phê duyệt'}</h1><p>Email: {profile.email}</p><p>{profile.status==='suspended'?'Liên hệ quản trị viên phòng xét nghiệm.':'Email đã xác thực nhưng chưa được phép truy cập dữ liệu nội bộ.'}</p><button onClick={onSignOut}>Đăng xuất</button></section></div>}
function EmptyModule({name}:{name:string}){return <section className="empty"><h1>{name==='dashboard'?'Dashboard Admin':name==='documents'?'Tài liệu & hồ sơ':name==='capa'?'Sự không phù hợp và CAPA':'Người dùng và phân quyền'}</h1><p>Phân hệ đã được dựng khung, chưa hiển thị số liệu minh họa như dữ liệu thật.</p></section>}
