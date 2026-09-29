using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TBot.Models
{
    public class VirtualGatewayDevice
    {
        public long Id { get; set; }

        public string Name { get; set; }

        public string ShortName { get; set; }

        public byte[] PublicKey { get; set; }

        public byte[] PrivateKey { get; set; }

        public long GatewayId { get; set; }
    }
}
