/*
   AI no SQL Server 2025                                              
                                                                                                    
   Rodrigo Ribeiro Gomes
   7 anos na Power Tuning
   Consultor -> Head de (SQL Server -> Inovação -> IA )

   https://iatalk.ing
   https://thesqltimes.com
   https://www.red-gate.com/simple-talk/author/rodrigor-gomes-2/
   https://www.linkedin.com/in/dba-rodrigo/
   https://devblogs.microsoft.com/azure-sql/author/rodrigor-gomes/
                                                                       
                                                                                                                                            
                                    ¦   ¦        ¦¦   ¦¦     ¦   ¦                          
ZëZZëZZZZëZëëëZZZëëëëëëëZëZZëZëëZZëëëëëëZZëZZZZZëZZëÆ    ÆNeZZZZZÕÆÆ    ÆNeZNÆÆÆ      ÆÆÆÆÆ    ÆNNNNëZZZZZZN             NëZZZeZZZZee 
 ZëëZëZëëëëëZëëZëëZZZZZZZZZZëZZZZëZZZZëZZZëëZëZZZëëZNÆ   ÆÆeZëëZZZZNÆn    ÆÆÆÆÆ      ÆÆÆëZZÆ¿   ÆNZZZZZZZZZZÕNNÆÆÆÆÆNÆNNNNNZZZZZZZeZZZ 
 ZZëZZZëëZZZëëZZZëZZëZZZZZZZZZZZZZZZZZZZëëZZZZZëZZëZÆÆ   ÆNeZZZZZZZZNÆ    ÕÆ¿     eÆÆÆZeZeZÆÆ   ÆÆeZZZeZeZeZZëÕNNÕëZZZZeeeeZZeeeZZeZZe 
 ëëZëZZZZZZëëZZZZZZZZëZZZëëëëëZZëZëZZëëëZZZZZZëZZZZëÆ¿   ÆZZZZZZZZZZZNÆ        ¦ÆÆÆN2eZeZZZNÆ   NÆeZZZeZZZZeZZZZZZZZZeZZZZZZZZZZZeZeZZ 
 ZZëëZëZZëëZZëZZëëëZZZZëëZZZZZZZZZëZZëZëZëZZZZZZëZZëÆ   2ÆeZZZZëZZZZZZÆÆ    ›  o¦ëÆÆÆÆÆÆÆÆNNÆ   ÆÆeZZZZZZZZZZZZZZZZZëZZZZZZeeeZeZZeZZZ 
 ëZZZZëZZZZZZZëZZZZëZZëZZZZZZëZZZZZZZZZZZZZZëZZZZZZZÆ   ZÆ2ZZZZZZZZZëZëÆÆ               ëÆÆÆÆ   ÆÆeZZeZeZZeZZeeZZZeeeeZZZZeZZZeZeZZZZZ 
 ZZëëëZZZZZZZZëZZëZZZZëZZZZZZZZZZZëZZZëZZZZZZZZZZZZëÆ   nÆeZZZZZZZëZZZZëÆÆÆÆÆÆZ                 ÆÕZZZZZZeZeZZZeZZZZZZZZZeeZZZeZZeZZZZe 
 ZëZZZZëëëëëZëZZëëZZZZZZZZZëëZZëZZZZZZZZZZëZZZëZëZëZÆ›   ÆÕZeeeeëëëëZZZëëZZëNÆÆÆÆÆÆÆÆn          ÆZZZZeZZZZZeZZZeeeZeeeZeZZeeZZZZeZeeee 
 ZZëëZZZZZZZZZZZZëëZZZZZëZZZZëZZZZëZZëZëëZZZZZZZZZZZÆn   NonëÕÕë2¿¿nnn22eëëëëëZZZZZÕÆÆÆÆÆÆÆÆ   ÆÆeeZZZZZZZZZZZeZZZZZZZeZZZZZZZeeeeeZZe 
 ëëZZZZZZZZëëZëZZZZëZZZëZZZZZZZZZZZZZZZZZZZZZZZëZZZeZëÆÆÆZÕÆNNZëëÆÆNÕÆNZno¿¿¿2eeZZZZZZZeZÆÆ    ÆëeZZZZZZeZZeeZeeZeZZeeeeeZZeZeeeZeeZZe 
 ZZZZZZZZZZZZZZZZëëZëZZZZZZZZZZZZZZZZZZZZZZëZZZZZZ2eÆÆÆëÆÆÆÆëeo¦¿e¿›n2ëeZëÆZÆë2eZeZeZZZZNÆ¦   ÆN2ZeeZeeZZZZZZZZZZeZZZZZZZZZeZZeZZeZeeZ 
 ZZëZZëZëZZZZZZëZZZZZZZZZZZZZëZZZZZZëZZZZZZZZZZZen2ÆNëÆNÆNn 2ÆÆÆÆÆ›nëNÆÆÆÕ2ëÆÆëneZZZëZZÆÆn   ëÆZZZZZZZeZZeZZeeZeZZZeeeeZeeeeeeeeeeZeeZ 
 ZëZZZZZZëëZëZZZZZZZZZZëZZZZZZZZZZZZZZZZZZZZZZZZeëÆÆ2 2NÆÕÆÆëZÆÆÆÆÆÆÆÆÆÆZÕëN2ZÕZ22ZZZZÆÆ    nÆÕeeZZeZZeZZZZZZZeZZZZeZZeeeeeeZZZeZZeeZZ 
 ZZZZëZëZZZëZZZëZZëZZëZZZZZëëëZZZZëZZZZëëZZZZZëëZëÕëëÆo në ëë2en › ›¿¦2ÆÆÆÆNëeÕNZ2ZZÆÆÆ    ÆÆNNNNÕZeZeZZeZZZeZeZZeeeZeZeZZZeeeeZZeZZee 
 ëZZëZZZZZëZZZZZZëZZZZZeZZZZZZZZZZZZZZZZZZZZZZë2ëëÕÆÆÆÆÆÆÆÆÆÕÆÕ¦          ÆÆÆÆÆÆNeÆÆÆ     ÆÆZ   ÆÆNNNNNNNNNNNNNNNNNNNNNNNNNÕeeeeeeeeeZ 
 ëZZZZëZZZZZZëëëZZZZZZZZZZZZZZZZZZëZZZZZZZeZZZÕneÆNNe            o¦ ›¦¿oo›  ÆÆÆÆNÆÆ      ÆÆN         ¿ÕNNNÕeo¿             NeeZZZeeeee 
 ZZZZZZëZZëZZZZZZZZëZZZZZZZZZZëZZZZZZZZZZZZZZëënen›         › ›    ¿o¦¦¿ono nÆÆÆ       ÆÆÕeNNÆ›                            NeeeeZeZZZZ 
 ZZZZZZZZZZZZZZZZëZZZZZZZZZZZZZZZZëZZZZZZZZZZÕÕnZ22e›   ¦¿¿¿¿¿n2e¦¿¦¦oon222¿ NÆÆ     ÆÆÆeeZeëNNNNNÆn              ›oneëÆNNNÕeeeeeeeZeZ 
 ZZZZëZZZZZZZZZZëZZZZZZZZZZeZZëeZeZZZZZëZZeZZÕNn›Zn   ›¦        ¿¦›¦    ¿o22››ÆÆ ›ÆÆÆNeeeZeeZeeZZëNNNNNNNNNNNNNNNNNNNNNNNNNÕeeeZeZZeeZ 
 ZZZZZZZZZZZZZZZZeZZZZZZZZZÕNNNNÕZZeZZZZZZZZZÕN  2  ¿n2e2NÆÆÆÆ2o›  ›       ¦n eÆÆÆNZeZëZZZZZZZZZeeZZeZZeeeeeZNn            NeZZZeZZeee 
 ZZZZZZZZëëZëZZZZëZZZZZZZëNNÆ¿¦ëÆÆëeZZZZZZZNÆÆÆ ¦Z            ëNN 2ÆNÆÆÆÆÆÆN2n¿Æ2ZZZeZeeeeZZeeZeZZeZZZZeZZZeZN            ¦NeZeeZZeZZe 
 ZZZZZZZZZZZZZëZëZeZëZZZëNÆ      nÆNZZZZZZNÆ   eN›   ¦ÆÆÆNÆÆnÆZ    2n2Z     ¿o ÆëZeZZZZZZeZeZZZeZeZeeeeZeeZeZNNëNÆÆÆNNNNNNNëeeeeeZZeZZ 
 ZZZZëZëZZZëZZZeZZZZZZZZNÆ         ÆNeeZZZÆ›o2  Õ               ¿›¦ëëZ¿ÆÆ¿NÆ2  ÆNNëeeeZeZZZZZeZeZZeeeZZeeZeeZeÕÕNÕëZeeeeeeeeZZZZeeeeee 
 ëZëZZZZZZZZZëZZZZZZZeZNÆ   ¿ÆÆÆ   nÆëeZZZÆ    onno¦›› ›¦      ›¿  ëën›   ono››› ¿NZeZZeZZeeZeZeeeZZZeeeeZeeeeeeeee22eeeeeeeeeZeeZZZNÆ2
 ZZëZZëZZZZZZZZZZZZZëZÕN  ›¦ÆÆÆÆÆZn ÆÆeÕNNÆ ¦ÆN 2o›         Õ2      2ë ›o¿  ›oe¿2nNZZZZZeZZZZZZZeeeeeeZZeeeeZZZZZZeZZZeeZeZZZZeeeeeÆÆ  
 ZZZZZZZZZZZZZZZZZZZZZNÆ ¦eÆ›     ¦nZÆÆÆ›  ¦ ¿¦ nn›¿›     oÆN›2ÆÆÆÆZN¦ën¿non2ne o2ÕZeeZZZeeZeZZeeeeZZeeZeZeeeeZeZZZZeeZZZZZZZZeZZZNÆ   
 ZZZZZZZZZZZZZZZZZZÕÆÆÆe en             Ze›     ¿¿››2o›  ¿Õ        2Zo2Õn ¦onne› NëZZZeZZZZZZZZeZZZeeZZZeZeZZee2eeeeeeeeeeeeeeeeeZÆ    
 ëZëZZZZZZZZZeZZZëÆÆÆ   ¿›                ÆÆÆ    ¿   ¿› Õe 2e2   e ÆÆ2¦   ¿22on ZNZZZZZZeeZZeZeeeeZeeZZeZeZeeeeZeeeeeeZZeZeZeeeeeëÆ    
 ZZeëZZZZeZZëëÕÕÆÆÆ    ë¦›ÆÆÆÆÆÆÆÆÆÆÆ       ÆÆÆÆ ¦›     ZNNÆÆÆÆÆÕÆNÕ¦nÆ2ë ¿onn¦ NëeZeZeëëZeeeZZZZZeeeeeeeeeZëNNNNNNZeZZZeeZZZeZeZÕÆ    
 ZZZZZZëNNÆÆÆÆÆÆÆ     o2  ÆZeZZZZeZëÆÆÆÆ     ¦Æ¿ ¿›                 ZÕNeNNnoo›¦NNZeZZNNNNÆNNZeeeeZeeeeZeZZZZNÕ    NNëeeeZeeeZeeeZëÆ    
 ZZZZZÕNÆ      o    ZÆ2¦ eÆeZZZZZZZZeZëÆÆÆ     ¦ ¿¦¦››¦›    ››   ÆZ  ›¦   ¦o¦ NNZeeeNN     ÆN2eeZeeZZZZeeeZNN  ››  ZÕeeeeeeZeZZeeZÆÆ   
 ZZZZÕN       e    ÆÆÆ › ÆNeeZZZZZeZZëZeëÆÆ¿  ÆZ 2nnnn›››        ¦¦ën¦on¿oo¦ NNZZZZëN  ›¦›  ÆZeZZeeZeeeZeeZN› ¦¦¦  ÕNeeZeeZeeeeeZeZÆÆÕ 
 ëZZZNZ   NÆÆÆ    ÆÆNÆ ¦ ÆNeZZZZeZZZZeZZZZNÆÕnÕe  ¿oeene¿¦›     ¦¦  ¦ ››¦¿ooNNZeeeeNN  ¦¦¦ oÆ2eeeZZeZeZeeeNÆ  ›¦¦  ÆëeeZeeZZZeeZeeNNNÆn
 ZZZZN› ›ZÆNÆ    ÆÆ2Në ¦ ÆÕeZZZZZZZZZZZZZZNÆe 2Z    ›neÆNoëÆÆÆ› oo ¿2¦ZëÆNZ¿NZZZeZZNn ¦¦¦  ÆÕ2ZeeeZeZeeZeZN  ¦¦¦› ÕN2eeeZeeZeZeeeNÆ ÆÆÕ
 ZZZZNÕ   ÆÆÆ   ÆÆeZNo   ÆZeZZeZZeZZZZeeZNN¿  n       ¿ZÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆZë ›NZeZeeNN  ¦¿¦ ¿ÆeeZeZeeeeeeeeNN  ¦¦¦  ÆÕeeZeeeeeeeeZÕÆ     
 ZZZZÕÆ    Æ   oÆZeZN›   ÆeZZZeZZZZZZëZZNN    Æ ¦       ¿›nÆÆÆÆÆÆÆÆÆÆÆÆN¿  nNZZZZeNZ ¦¦¦  ÆNeeeZeeZeeeeZZN› ¦¦¦› ëÆeeeeZZZeZeeZZÆÆ     
 ZZZZZNN   o   ÆN2eZN   ›ÆeeZZZZZZeZeZZNN¦   ÆÆ  ››           ›onn¿¦  ¦ ›¿›eNZeeZÕÆ  ¦¦¦  ÆëeeZZeeZZZZeeNN  ¦¦¦  ÆÕ2eeeeeeeeZZeëÆ      
 ZZZZZZNÆ›  ëZ2ÆNeeZN   ¿ÆeeZZeZZZZZeëNN    ÆN     ›               ¦no¿¦oo nÕ2eeZNe ¦¦¦  ÆN2eeeeeZeeeeeeN2 ››¦› eÆ2eeeeeeeeZeeZÕÆ      
 ZZZZZZZÕÆÆn2o  ÆÆNZN   ¿ÆeeZZZZZëëëZZo  oÆÆÆÆÆ    ››  ¦  ›  › › ¿ee2noonn¦ÆN¦¦¿eN  ¿¦›  ÆZ2eeeeeeeeeeeëN  ¦¦¦  ÆÕneeeeeeeeeeeeZÆÆÆÆÆë 
 ZZZZZZZZÕÆ  Æe   ÆÆÆ   ¿ÆZëÕëZZZ2¿nÕNÆÆÆÆNZZZÆÆ        ››    ›o¦oZn¦¦›¿o2¦ ÆÆÆÆZ       ÆÆÕNNNNNNNNNNNNNN ›¦¦¦ ÆÆNNNNNNNNNNëeeeeeeeZÕÆ¿
 ZZZZZZZZëÆ   ¦     Æ¦   ÆëeZ2ÆÆÆNÆNëZeZeZZZee2ÕÆÆ›       ¿o›   ››oo›¿¿nnoo NÕÕÆÆÆÆÆÆ   e  ¦nëNNÕZeo¦     ¦¦¦¦            NÆÕeZZeeeeee 
 ZZZZZZZZëÆ   ÆÆ¿    2ÆÆÆÕno2¦   ››¿2ZeZeeZeZZëZ2ÕÆÆÆ     ›¦o¿¦2no¦››¦oeo   ZëÕÕNÕNNÆÆÆÆÆÆÆÆ›           ››¦¦¦¦¦›¦›¦¦¦¦¦¦›  ¦ÆeeeZeeeee 
 ZëZZZZZZZÆ¦   ÆNÆÆÆÆNNëZZNënZNëN2onn2oeeee2eeeeëe2eÆÆÆÆÕ                 NÆÆÆÕZZÕeNëëÆ     ÆÆÆÆÆÆÆ¿      ¦¿¦¦¦¦¿¦¦¦¦¦¦¦¦› ›ÆeZÆÆÆÆÆÆÆÕ
 ZZZZZZZZZÆÆ   ÆÆo2Zen22222ZZÕÕ2ZÆNë2nZëneÕZe2eëeeZen2NÕÆÆÆÆÆÆÆe› ›¦oëÆÆÆÆÆÆZZÕëëNëeNNÕÆoo   ÆëëZëÆÆÆÆÆÆ2   ¦¦¦››››››      ÆNeNÆ       
 eZZZZZZZZNÆ    en2ee2ee2nn22ZnnënnNe2nëÆ2oNëZ222Õe2eeonÆëëZÕÆÆÆÆÆÆÆÆÆÆë2ZÆeeeeeZeNeeNNNÆÆÆÆÆN2ÆëZ2NÕZÆNNÆÆ              ÆÆNeeÆN       
 ZZZëZZZZëNÆ   ÆÕ222222nÕëe22nZZeeZ2N2e2N2eoN2Õee2Zëeeë2nëëZenn2Ze22222eeNeeeZZZeeNZe2NëZZZZZëZ2ëNZnÆeëÆoÆÆÆÆÆNNNNNNNNNNNë22eZÆ¿       
 ZZZZZZZZNN   ÆÕ22222n2n2nZeZnnnnZeeÕÕZneZeeëN2Zeee2ÆeeZZ2nÕ2eZennNÕeeZeZeeZZZeëeZ2ÕZZeÕZZëZZZZZenÆ2ZÆ2Æ¿ÆnëNÆo¿222eeee2e2ZeeëÆ        
 ZZëZZZZZNe  NNe22222eennnnneÆënnn22nëëZÕZ22¿Æ2eeeeeoëë2eZenÕeZZÕeoeÆZeeZZZZZZeÕZZeZZeZZZZZZZZZZZZ¦ÆoN2ÆeÆoÆëëÆe¿eeeeeeeZeeeeNÆ        
 ëZZeZZZëN  ›Õee2ee222eë22n2nn2ëÆN2nn2Õ2eene2eëeZeZZZ2ÕZëNÕÕZeÕeÆeÕnoNÕZeeZZZZeeÕZÕNÆÆÆÆÆÆÆÆÆÆÆZZÕN2ë¿ÕëÆeëÆ2ëNÆeo2eeeeeeeZeeÆÆ        
 ZZZëZZZÕÆ  në2e222ne222neÕe2nnnnnNÆZnZÕN2neenZeeZeeeenPOWER TUNING POWER TUNING POWER TUNING POWERZZZëëNnÕÆ2ZÆZeNëeÆ2¿2eeeZeeeeeÆ›       Æ
 ZZZZZeZëN  ë2n22nn22n222nnneëë2222eNÆÕNNëo2eeeeeeeZeeePOWER TUNING POWER TUNING POWER TUNING POWERZëZZÕÕëZZeNZ2NÕnNÆÆÕoeeeeeeeeZÆ         
 ZZZZëZZëÆ  Zn2neen2e22nnn222e22ÕÕ222ëÆÆNn2222eeee2eeeëPOWER TUNING POWER TUNING POWER TUNING POWERÆëëëëNÕëë2nZÆëëÆNÕÕÆnneeeZeeeNÆ         
 ZZZZZZZZNÆ nn2e222e222ZZZ2nnn2222eÕZeëÆÆ¿22eeeeeeZZeZZPOWER TUNING POWER TUNING POWER TUNING POWERëëëëëÕNÕZëNëëNÆëZëÕNëoeeeeeZeÆZ         
 ZZZZZZZZëÆe›ne2n2222222n22ZZÕee2222e2eÕÆ222eeeeeeeeeeëPOWER TUNING POWER TUNING POWER TUNING POWERÆëëÕÕZëÆÆeZÕZ2enNNNÆÆo2e2eZeZÆ          
 ZZZZZZZZZÆ¿neoo22222222e22n222eeeeÕÆÆÆÆÆÆÆ2eeeZeeeeZZZPOWER TUNING POWER TUNING POWER TUNING POWERëëÕëÕëÕÆNeeZZÕNNÕëëÕNëoeeZeeÕÆ          
 ZZZZZZZZëN¦oeÆÕZ2oon2222nn2222eÆÆÆÆ¦     ÆÆÆÆÆNZZZeeeePOWER TUNING POWER TUNING POWER TUNING POWERZëëëëëëÆëeëZZZZeZëëÕÕN¿2eeeZÆÆ        ÆZ
 ZZZZZZZZëÕ¦2n2nnZÆÆë22n2een22nëÆ              ÆÆÆNëeeeeeZZZZZZZëZeÕZÆÆÆëÕÆÆÆÆÆÆëZZZZëëëÆÆÆÕZëëëÕëÕÕëNÆZZZZZëëÕÕëëZëNëoeZZZÆ¿       ZÆ 
 ZZZZZZZZëÕ›ne22eno¿n2eZë2ZZZZëÆ      nooeÕ›      NÆNNZZZZZZZZZëëÕÕoeÕÆN¿Zë2eeZeeeZeZeZZZZZZZZZëëÕëZÕÆÕeeZZZZëZZëNÆÆÆNo2eeZÆ        ÆÆ 
 ZZeZëeëZZN¦o2222neZën2eëNÆÆÆÆÆÆÆ  ¦ÆÆ›    ¦ÕÕë›    ¿ÆÆÆNZZZZeZë2ÕÆëoëÆÆ2eë2ZeeeeeZeZeeZZZZZZëëëëÕëZÆÆëe2ëëëëÕNNëeeZëÆëoeZëÆ eÕNÆÆÆÕÆZ 
 ZëZZZZZZëN2›e22eZe2ÕNÆÆëe            onen¿    ¦ëZ›    nÆÆëeZZeëë2ÆN¿nÆÆenN2ZeZeZZZZZZZeZZëeNÕëÕëëëëÆÆëe2ÕÆÆÆÆNNNNÆNÕÕÆÕneZNNÆÆNNNNÕZe 
 ëZZZZëZZZëÆ›n2ZZëNÆÕ           ›eÆÆÕÕ¿    ¦Zë   ¦ÕZe    ëÆÕëëeëNnZÆe¿ëÆN¿ÕeeZee2eeZZeeZZÕZ2NÕÕNÆÆÆNÆÆÆÆÆÆ¿    ¦oenZÆÆÆÆÆZZeZZZZeZeeeZ 
 ZZZZZZZZZZN›¿eeNÆ¦    ››     ¦¦››     oÕ   o›2ë¦    ¿ën¦¿›ÆÆÆÕnÆZnNNnoÆÆoZëZeZZeëZZZZZëNÆÆÆÆÆÆÆÆ¿eÆÆÆ¦     ¦¦  ››      ¿ÆNZeeeeeeeeZe 
 ZZZëëZZZZZNë2eNo    ¦  ›    ›¦›¦oZN¦   o ZÕn  nZn¿    NZ¿o eÆN2ëNe2ÆÕ¿ÕÆëoÕZZZN2NNÆÆÆÆÆÆ        ¦   e› ¦  ¿Õ¿¦¿¿e¿n¿on¿¦oÕÆÆÆÆÆÆÆÆÆÆÆÕ
 ZZZZZZZZZZëNnen  ›››          ¦ ¦¦nÕÆÆ2    ›NZ››o¿›  2NNe2e¦ÆÆÆÕNÕZZÆnnÆÆnÆÆÆÆÆÆÆÆÆÕ       oooo› o2ooÆZo   ›¦2Õ¦¿eoon¦Zo¦¿            
 ZZZZZZZZZZZÕZÆ  ¦¦¿¿› ›         ›››¦¦nëÆNeNN›¿Õ¿¦ooNÕZëeZZëenÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆn         ›¦oo¦›  oo¿¿onn¿ëÆ›  ¦ ¦o2n nono¿¿2ëÆ¿          
 ZZZZZZZZZZZZÕÆ  ¦o¿oo¿¿› ›       ››¦››¿oZëÆNÆÆëo¦›                             ›¦¦›¿¿no¿n¿¿noooon¿nn2n›ÆÕ›Z   › n¿2Zoeeo2¿ZÆ        › 
 ëëëëëëëëëëëÕNNÆ  ¦¦¦oooo¿›           ›› ›               ¦››¿›¦¦o¿ ¦¦¿n¿¿o¦¦›o¿¦¿›¿o¿¿o¦o¿¦¿¦¿¿›onnnnnn¿oÆN¿› ›  2›¿ ›oe¿2eoëÆ         
ÕÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆ›  ¦¿¦›¿o¿o›››                        ¿¦¿n¿¦oo¦¿oo¿›¦n¦›ooo¿¿n ›nn¿¦¿›››¦ ¿¦¦›  ¿e22oo oZÆ ÆZNN2o›ÆÆn¿o2ne¿eÕÆÆÆ      
                ÆÆë  ¦¿¦›¿¿¦¦›       ›        ¦¦¦¿¦¦on¿o¿¦› ¦›¦¿¦¦¦¦¦¿¿o¦¦¿¿¦¿  ›¦¦¦onnnnonn222nZeno¿¦¦on2ÆÆÆ› oe¿2n ›o›ZnoZe› Æ       
                 nÆÆ  ¦¿¦¦o¦¿n¿   ›¦¦¦¿¦›¦onoeee2e2nnon¿¦¦¦¿o›¦¦¦¦¦›¦¿¦››¿¿›  ¿22e22n22nn22¦ ›¿2o   2ÆÆÆÆÆe›o2eZZZë¦2¿n¿nooen2¦Æ       
NÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÕÆÆ¦  ¦¿o¿¿¿¿¿¦ › ¿noneZëëZZno¦¦›o ››¦¦     ¦››¦¦¦¦¦o¿oo› eëZeen22e222n¦›ëÆÆÆÆÆÆÆëe¦     ee2no22Õ››ëo¿ooÕeZZnÆ    ›› 
 ZZeeZeeZeZZeZZeZëeeNÆÆ   ¿›¿¿¿¿¦    ›¦¿¿¿¿¦›      ¦›¦¿¿¿¿oo2nooon2nnn22n¦Zëe22Z2n2o¿¿›¦ëÆÆÆÕZe2n¿oo¦›  ëÕZn¿o¿oonÕ  noo22Zn¦›eÆ       
 ZZZZZZZZZZZZeZZZZNÆÆÆÆÆÆ ›¿¿¦¿nno             ›¦oo¿¿ooo2ne2n222nnnneeenoÕZZe2o¿¦¦¦¿oZÆNë2n¿o¦¦¦¿¿o¿¿ÆÆÆÆNÆNÆNZZeZë   ›oNn›oÆÕÕe       
 ZëëëëZëZZZZëëëZÕÆÆo ÆÆNNÆZ ¦ono¿oeo          ›¿n¿¦¿n¿¿ooonnnno222eZnoonZo¦¦›¦›››¿2ÕÕnnnno2noooonoe2n›› ›     ZeZëNÆÆÆÆÆÆÆN¿n¿Æ        
 ëZZZZZëZZZZZZëNÆÆ    enoeÆÆ  o22ooo2e¿       › ››¦¦¦22nn2nnnn2222¿¦nno¿ ›¦› ›¿ZNë2no¿¿o¿¦¦¦¿¿oo¿¿¿¿¿¿¦   ZÆNÕëZeÕÕëNÆë ››¿no2Æ        
¦NëëëZëZÕNNNNNNÆe    NÆNÆÆëeÆ¿  o2o¿›¦n2e2on¿onoone2eeZonno¦¿¦o¿¦ ›¿¦›››¿¦n2ÕÆNÕÕëe2e2o¿¿no¿o¦¿¿oo¿¿¦¿oÕÆÆÆNÕëeeZëÕn› ›n›¦ n ëÆ       o
 NëZZëëëN¿    ÆÆ   ¦ÆÆÕeë¦oÕÆÆÆ          ¦on22nooo22nno¿ooon22o¦›o22¿›   ¦¿o¦¿¿¿on2nZNÕÕZnnoonnoonoonn¿›     ¿ëÕë    › ›2eëÆÕÆ›       Æ
 NëZZZëZNe NN›Æ    ÆNNNNNNÆeÆëÕÆÆ›    ¿n22nnn2ZëZ2¿¦¿¦¿onno¿  ›¿     oÆÆÆÆ2›     ›oo¿¦¦¦nëNNNÕëZe2n22nno¦›¦ÕNëe  ›ëNëZZn2nëënÆ        Æ
¦ëÆÆëZëëNe NZoÆ   ÆÆ     ÆÆÆÕnÕÕNÆÆÆ¿            ›¦¿¿¦         ¿ÕÆÆÆÆÆÆNÕÆÆÆÆÆÆÆo     ooo¦¦¦¦¿¿o2eZZe2¿nÕÆNënn2eee22n2eeNNZ eÆoÆÆÆÆÆZÕë
 2NNZZëÕNe NNZ›  ZÆN ëNN¿ ZÆn2ZnëNÕÆÆÆÆÆÆÆÆÆÆÆÆÆÆn   ¦eÕÆÆÆÆÆÆÆÆÆÆNÕëëÕëëÕëZZÕÆÆÆÆÆÆÆ2       ›¿n¿¿¦› ZÆÕe¦ 2ëëZëëeëëZëëZ¿¦›¦NÆÆÆÆÆÆÆÆN¦
 eÆNeZZëëN   Æ   ÆÆN  NNo ÆÆ¦2oÕNZZZëÕÕNÕÕNNÆÆÆÆÆÆÆÆÆÆÆÆÆÆëëëëëëÕÕÕÕÕÕÕÕÕÕÕÕëÕëZZZZëÆÆÆÆÆÆÆÆ2›      › ›¦¿oo››          ››  ZNëëëëZZëZZ 
 ZÆNëÕëëÕNNNNÆ   ÆÆN› NNe Æe›2ÆÆeeëZëëëëÕNÕÕNNNNNNÕÕëëëëëëÕÕÕÕÕÕÕÕÕÕÕÕÕëëÕëëëëëëëëëÕëZeZNNÆÆÆÆÆÆÆÆÆÆÆÆÆNÆÆÆÆNNNNNNNNÆNÕ2eNNNÕZëëëëëëëë 
  oo¿ooo¿¿¦¦›ë    ëo  n¿     ¦           ››¦¦¦¿¦¿¿¿¿oooo¿¿o¿o¿¿¿¿¦¦¦¦¦¦¦¿¦¦¦¦¦¦¦¦¦¦¦›¦¿¿ ›¿¦››22on2n2¿ono¦oZ›››¦›¦¦¦¿on2no¦›››               

*/

	-- sp_invoke_rest_endpoint  (ExternalHTTP.sql)
	-- CREATE EXTERNAL MODEL | AI_GENERATE_EMBEDDINGS  (AI.sql)
	-- vector data type	 (AI.SQL)
	-- Copilot no SSMS

