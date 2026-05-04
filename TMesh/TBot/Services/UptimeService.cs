using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TBot.Services
{
    public class UptimeService
    {
        public DateTime Started { get; private set; }

        public TimeSpan Uptime => DateTime.UtcNow - Started;

        public void Reset()
        {
            Started = DateTime.UtcNow;
        }
        
    }
}
