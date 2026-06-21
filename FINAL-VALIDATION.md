# Boot performance validation

```powershell
.\Validate-BootPerformance.ps1
.\Validate-BootPerformance.ps1 -MaximumBootSeconds 90
```

Created by **Dewald Pretorius**. This read-only validator checks the latest Windows boot-performance event against a configurable threshold. Exit codes: `0` healthy, `1` warning, `5` collection failure.
