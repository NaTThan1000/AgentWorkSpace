import fs from 'node:fs';

// Windows may briefly deny rename after writes. Retry only bounded access errors;
// every attempt must still see an absent destination owned by no other writer.
export function publishDirectory(staged,target,{
 platform=process.platform,rename=fs.renameSync,
 wait=ms=>Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,ms),
 delays=[25,50,100,200,400,800],
}={}){
 for(let attempt=0;;attempt++){
  try{fs.lstatSync(target);throw Object.assign(Error('destination appeared during publication'),{code:'EEXIST'});}
  catch(error){if(error.code!=='ENOENT')throw error;}
  try{rename(staged,target);return;}
  catch(error){
   if(platform!=='win32'||!['EPERM','EACCES','EBUSY'].includes(error.code)||attempt>=delays.length)throw error;
   wait(delays[attempt]);
  }
 }
}
