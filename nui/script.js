(function () {
    'use strict';

    const curtain = document.getElementById('curtain');
    curtain.classList.add('hidden');

    function reply(id, uri) {
        fetch(`https://${GetParentResourceName()}/converted`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ id, uri }),
        }).catch(() => {});
    }

    function convert(data) {
        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.onload = () => {
            try {
                const w = data.size || img.naturalWidth;
                const h = data.size || img.naturalHeight;
                const canvas = document.createElement('canvas');
                canvas.width = w;
                canvas.height = h;
                const ctx = canvas.getContext('2d');
                ctx.imageSmoothingQuality = 'high';
                ctx.drawImage(img, 0, 0, w, h);
                reply(data.id, canvas.toDataURL('image/png'));
            } catch (e) {
                reply(data.id, '');
            }
        };
        img.onerror = () => reply(data.id, '');
        img.src = data.src;
    }

    window.addEventListener('message', (e) => {
        const data = e.data || {};
        if (data.action === 'show') {
            curtain.classList.toggle('no-spinner', data.spinner === false);
            curtain.classList.remove('hidden');
        } else if (data.action === 'hide') {
            curtain.classList.add('hidden');
        } else if (data.action === 'convert') {
            convert(data);
        }
    });
})();
